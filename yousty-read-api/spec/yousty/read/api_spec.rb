# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Yousty::Read::Api do
  it "has a version number" do
    expect(Yousty::Read::Api::VERSION).not_to be nil
  end
end
