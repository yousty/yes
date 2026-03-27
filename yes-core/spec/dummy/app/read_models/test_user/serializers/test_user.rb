# frozen_string_literal: true

module ReadModels
  module TestUser
    module Serializers
      class TestUser < Yes::Core::Serializer
        set_type :test_users

        attributes :name, :email
      end
    end
  end
end
