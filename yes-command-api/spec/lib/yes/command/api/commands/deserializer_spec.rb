# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Yes::Command::Api::Commands::Deserializer do
  describe '.call' do
    subject { described_class.call(params) }

    let(:command1) { 'DoSomething' }
    let(:command2) { 'DoSomethingElse' }
    let(:command3) { 'DoSomethingElse' }

    let(:subject1) { 'Activity' }
    let(:subject2) { 'Activity' }

    let(:data1) { { what: 'something', id: SecureRandom.uuid } }
    let(:data2) { { what: 'something else', id: SecureRandom.uuid } }
    let(:data3) { { what: 'something else 3', id: SecureRandom.uuid } }

    context 'command instantiation' do
      let(:params) do
        [
          {
            context: 'Dummy',
            subject: subject1,
            command: command1,
            data: data1
          },
          {
            context: 'Dummy',
            subject: subject2,
            command: command2,
            data: data2
          }
        ]
      end

      let(:deserialize_error) { Yes::Command::Api::Commands::Deserializer::DeserializationFailed }

      it 'instantiates commands' do
        aggregate_failures do
          expect(subject[0]).to be_a(Dummy::Commands::Activity::DoSomething)
          expect(subject[0].attributes).to include(data1)
          expect(subject[1]).to be_a(Dummy::Commands::Activity::DoSomethingElse)
          expect(subject[1].attributes).to include(data2)
        end
      end

      context 'when command is not found' do
        let(:command2) { 'DoSomethingNotFound' }

        it 'raises DeserializationFailed error' do
          expect{ subject }.to raise_error(deserialize_error)
        end
      end

      context 'when command data is invalid' do
        let(:data1) { { what: 1, id: SecureRandom.uuid } }

        it 'raises DeserializationFailed error' do
          expect { subject }.to raise_error(deserialize_error)
        end
      end

      context 'when some commands has metadata' do
        let(:metadata1) { { some: 'metadata' } }
        let(:metadata3) { { some: 'metadata 3' } }

        let(:params) do
          [
            {
              context: 'Dummy',
              subject: 'Activity',
              command: command1,
              data: data1,
              metadata: metadata1
            },
            {
              context: 'Dummy',
              subject: 'Activity',
              command: command2,
              data: data2
            },
            {
              context: 'Dummy',
              subject: 'Activity',
              command: command3,
              data: data3,
              metadata: metadata3
            }
          ]
        end

        it 'instantiates commands' do
          aggregate_failures do
            expect(subject[0]).to be_a(Dummy::Commands::Activity::DoSomething)
            expect(subject[1]).to be_a(Dummy::Commands::Activity::DoSomethingElse)
            expect(subject[1]).to be_a(Dummy::Commands::Activity::DoSomethingElse)
          end
        end

        it 'sets metadata' do
          aggregate_failures do
            expect(subject[0].metadata).to include(metadata1)
            expect(subject[1].metadata).to be_nil
            expect(subject[2].metadata).to include(metadata3)
          end
        end
      end

      context 'when params include a command group' do
        let(:command2) { 'DoSomethingCompounded' }
        let(:subject2) { 'Company' }

        let(:company_id) { SecureRandom.uuid }
        let(:user_id) { SecureRandom.uuid }
        let(:data2) do
          {
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
          }
        end

        it 'instantiates commands' do
          aggregate_failures do
            expect(subject[0]).to be_a(Dummy::Commands::Activity::DoSomething)
            expect(subject[0].attributes).to include(data1)
            expect(subject[1]).to be_a(Dummy::Company::Commands::DoSomethingCompounded::Command)
            expect(subject[1].payload[:dummy]).to eq(data2)
          end
        end

        context 'when command group data is invalid' do
          let(:data2) { { what: 1, id: SecureRandom.uuid } }

          it 'raises DeserializationFailed error' do
            aggregate_failures do
              expect {
                subject
              }.to raise_error { |error|
                expect(error).to be_a(Yes::Command::Api::Commands::Deserializer::DeserializationFailed)
                expect(error.extra[:invalid]).to be_an(Array)
                expect(error.extra[:invalid].size).to eq(1)
                expect(error.extra[:invalid].first[:command]).to eq('DoSomethingCompounded')
              }
            end
          end
        end
      end
    end
  end
end
