# frozen_string_literal: true

require 'bundler/setup'
require 'rails/all'
require 'yousty/eventsourcing'
require 'zeitwerk'
require 'yousty/api' # for serializers

module Yes
  module Core
    class Error < StandardError; end

    # Base command class for all commands in the system
    class Command < Yousty::Eventsourcing::Command; end

    # Base event class for all events in the system
    class Event < Yousty::Eventsourcing::Event; end

    # Base command handler class for all command handlers in the system
    class CommandHandler < Yousty::Eventsourcing::Stateless::CommandHandler; end

    class << self
      def loader
        @loader ||= begin
          loader = Zeitwerk::Loader.new
          loader.tag = 'yes-core'
          loader.push_dir(File.expand_path('..', __dir__))
          loader.ignore("#{__dir__}/core/version.rb")
          loader.collapse("#{__dir__}/core/models")
          loader.setup
          loader
        end
      end
    end
  end
end

require_relative 'core/version'
Yes::Core.loader.eager_load
