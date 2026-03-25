# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Auth::Subscriptions do
  describe '.call' do
    subject(:call) { described_class.call(subscriptions) }

    let(:subscriptions) { double('subscriptions') }

    it 'raises NotImplementedError' do
      expect { call }.to raise_error(
        NotImplementedError,
        'Auth subscription builders need to be ported from yousty-eventsourcing'
      )
    end
  end
end
