# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Yes::Read::Api do
  it "has a version number" do
    expect(Yes::Read::Api::VERSION).not_to be nil
  end
end
