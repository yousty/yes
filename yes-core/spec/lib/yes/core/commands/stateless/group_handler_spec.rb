# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Stateless::GroupHandler do
  let(:company_id) { SecureRandom.uuid }
  let(:user_id) { SecureRandom.uuid }
  let(:command_group) do
    Dummy::Company::Commands::DoSomethingCompounded::Command.new(
      company: {
        company_id:,
        name: 'New Company Name',
        description: 'New Company Description'
      },
      user: {
        user_id:,
        first_name: 'John',
        last_name: 'Doe'
      }
    )
  end

  let(:instance) { Dummy::Company::Commands::DoSomethingCompounded::CommandHandler.new(command_group) }

  describe '.handler' do
    subject { test_class.handler(handler_or_method_name) }

    let(:test_class) do
      Class.new(described_class) do
        def self.to_s
          'TestContext::TestSubject::CommandGroupHandler'
        end
      end
    end

    before do
      stub_const('TestContext::TestSubject::Commands::TestCommand::Handler', Class.new)
    end

    context 'when given a string' do
      let(:handler_or_method_name) { 'TestCommand' }

      it 'adds a command class to handlers' do
        subject

        expect(test_class.handlers).to contain_exactly(
          TestContext::TestSubject::Commands::TestCommand::Handler
        )
      end
    end

    context 'when given a symbol' do
      let(:handler_or_method_name) { :custom_handler_method }

      it 'adds a symbol to handlers' do
        test_class.handler(:custom_handler_method)

        expect(test_class.handlers).to contain_exactly(:custom_handler_method)
      end
    end
  end

  describe '#call' do
    subject { instance.call }

    context 'when all commands are valid' do
      before do
        allow(instance).to receive(:custom_check)
        allow(instance).to receive(:custom_method)
      end

      it 'executes all commands in the group' do
        subject

        expect(instance).to have_received(:custom_check).at_least(:once)
        expect(instance).to have_received(:custom_method).at_least(:once)

        events = PgEventstore.client.read(
          PgEventstore::Stream.all_stream,
          options: { direction: 'Backwards', max_count: 3 }
        )

        expect(events.map(&:type)).to contain_exactly(
          'Dummy::CompanyNameChanged',
          'Dummy::CompanyDescriptionChanged',
          'Dummy::UserNameChanged'
        )
      end
    end

    context 'when commands are invalid' do
      let(:command_group) do
        Dummy::Company::Commands::DoSomethingCompounded::Command.new(
          company: {
            company_id:,
            name: 'Invalid name',
            description: 'New Company Description'
          },
          user: {
            user_id:,
            first_name: 'John',
            last_name: 'Invalid last name'
          }
        )
      end

      it 'raises an error with details about failed commands' do
        aggregate_failures do
          expect {
            subject
          }.to raise_error { |error|
            expect(error).to be_a(Yes::Core::Commands::Stateless::GroupHandler::CommandsError)
            expect(error.extra).to be_an(Array)
            expect(error.extra.size).to eq(2)

            error.extra.each do |failed_command_info|
              expect(failed_command_info).to be_a(Hash)
              expect(failed_command_info.keys).to include(:extra, :error)
            end

            expect(error.extra[0]).to eq(command: 'Dummy::Company::Commands::ChangeName::Command', error: 'Invalid name', extra: { foo: 'bar' })
            expect(error.extra[1]).to eq(custom_handler: :custom_check, error: 'Invalid last name', extra: { boo: 'far' })
          }
        end
      end

      it 'does not publish any events' do
        read_all = lambda {
          PgEventstore.client.read(
            PgEventstore::Stream.all_stream,
            options: { direction: 'Backwards', max_count: 100 }
          )
        }

        expect do
          subject
        rescue Yes::Core::Commands::Stateless::GroupHandler::CommandsError
          # Ignore the expected error
        end.not_to(change { read_all.call.count })
      end
    end

    context 'when a custom handler method is missing' do
      it 'raises an error' do
        allow(instance).to receive(:send).with(:custom_method).and_raise(NoMethodError)

        expect {
          subject
        }.to raise_error(Yes::Core::Commands::Stateless::GroupHandler::CustomHandlerMethodMissingError)
      end
    end
  end

  describe '#initialize' do
    let(:invalid_command) do
      Dummy::Actions::Commands::DoSomething::Command.new({ what: 'something', id: SecureRandom.uuid})
    end

    it 'raises an error with the correct message if the command is not a valid CommandGroup' do
      expect {
        described_class.new(invalid_command)
      }.to raise_error(
        Yes::Core::Commands::Stateless::GroupHandler::InvalidCommandGroupError,
        "command Dummy::Actions::Commands::DoSomething does not match handler Yes::Core::Commands::Stateless"
      )
    end
  end
end
