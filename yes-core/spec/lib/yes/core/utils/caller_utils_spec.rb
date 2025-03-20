# frozen_string_literal: true

RSpec.describe Yes::Core::Utils::CallerUtils do
  describe '.origin_from_caller' do
    subject(:origin) { described_class.origin_from_caller(caller_location) }

    let(:caller_location) do
      instance_double(
        Thread::Backtrace::Location,
        absolute_path: absolute_path,
        path: 'irb'
      )
    end

    context 'when Rails is defined' do
      let(:rails_root) { '/path/to/rails/root' }
      let(:absolute_path) { "#{rails_root}/app/services/user_service.rb" }

      before do
        stub_const('Rails', double(root: double(to_s: rails_root), logger: double))
      end

      it 'returns formatted origin string without Rails root path' do
        expect(origin).to eq('App > Services > UserService')
      end
    end

    context 'when Rails is not defined' do
      let(:absolute_path) { '/path/to/app/services/user_service.rb' }

      before do
        hide_const('Rails')
      end

      it 'returns formatted origin string with full path' do
        expect(origin).to eq('Path > To > App > Services > UserService')
      end
    end

    context 'when absolute_path is nil' do
      let(:absolute_path) { nil }

      it 'uses path instead' do
        expect(origin).to eq('Irb')
      end
    end
  end
end
