# frozen_string_literal: true

require 'cerbos'
require 'dry-inflector'
require 'dry-schema'
require 'dry-struct'
require 'dry-types'
require 'pg_eventstore'
require 'zeitwerk'

module Yes
  module Core
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

# Backward-compatible aliases — canonical location is the organized namespace,
# but these aliases keep Yes::Core::CommandBus etc. working.
module Yes
  module Core
    # Commands
    CommandBus = Commands::Bus
    CommandProcessor = Commands::Processor
    CommandResponse = Commands::Response
    CommandGroupResponse = Commands::GroupResponse
    CommandGroup = Commands::Group
    CommandHelper = Commands::Helper
    CommandNotifier = Commands::Notifier
    CommandValidator = Commands::Validator

    # Authorization
    CommandAuthorizer = Authorization::CommandAuthorizer
    CommandCerbosAuthorizer = Authorization::CommandCerbosAuthorizer
    ReadRequestAuthorizer = Authorization::ReadRequestAuthorizer
    ReadRequestCerbosAuthorizer = Authorization::ReadRequestCerbosAuthorizer
    ReadModelAuthorizer = Authorization::ReadModelAuthorizer
    ReadModelsAuthorizer = Authorization::ReadModelsAuthorizer

    # Read Model
    ReadModelFilter = ReadModel::Filter
    ReadModelBuilder = ReadModel::Builder
    FilterQueryBuilder = ReadModel::FilterQueryBuilder
    EventHandler = ReadModel::EventHandler

    # Utils
    HashUtils = Utils::HashUtils
    ErrorNotifier = Utils::ErrorNotifier

    # Stateless
    module Stateless
      Handler = Commands::Stateless::Handler
      Response = Commands::Stateless::Response
      GroupHandler = Commands::Stateless::GroupHandler
      GroupResponse = Commands::Stateless::GroupResponse
      Subject = Commands::Stateless::Subject
      HandlerHelpers = Commands::Stateless::HandlerHelpers
    end

    # Command Helpers (kept for backward compatibility)
    module CommandHelpers
      HelpersV2 = Commands::Helper
    end

    # Command Notifiers (kept for backward compatibility)
    module CommandNotifiers
    end
  end
end
