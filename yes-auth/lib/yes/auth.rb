# frozen_string_literal: true

require 'yes/core'
require 'zeitwerk'

module Yes
  module Auth
    class << self
      # @return [Zeitwerk::Loader] the configured Zeitwerk loader for yes-auth
      def loader
        @loader ||= begin
          loader = Zeitwerk::Loader.new
          loader.tag = 'yes-auth'
          loader.push_dir(File.expand_path('..', __dir__))
          loader.ignore("#{__dir__}/auth/version.rb")
          loader.setup
          loader
        end
      end
    end
  end
end

require_relative 'auth/version'
Yes::Auth.loader.eager_load
