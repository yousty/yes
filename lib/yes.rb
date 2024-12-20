# frozen_string_literal: true

require 'bundler/setup'
require 'rails/all'
require 'yousty/eventsourcing'

# Core functionality & utilities
require_relative 'yes/configuration'
require_relative 'yes/version'
require_relative 'yes/type_lookup'
require_relative 'yes/aggregate/dsl/class_name_convention'
require_relative 'yes/aggregate/dsl/constant_resolver'
require_relative 'yes/concerns'
require_relative 'yes/read_model_class_resolver'
require_relative 'yes/concerns/has_read_model'
require_relative 'yes/command_utilities'

# Attribute method definers
require_relative 'yes/aggregate/dsl/attribute_method_definers/base'
require_relative 'yes/aggregate/dsl/attribute_method_definers/change_command'
require_relative 'yes/aggregate/dsl/attribute_method_definers/can_change_command'
require_relative 'yes/aggregate/dsl/attribute_method_definers/accessor'

# Class generators
require_relative 'yes/aggregate/dsl/class_generators/command_class_generator'
require_relative 'yes/aggregate/dsl/class_generators/event_class_generator'
require_relative 'yes/aggregate/dsl/class_generators/handler_class_generator'

# Main classes
require_relative 'yes/aggregate/dsl/attribute'
require_relative 'yes/aggregate'


module Yes
  class Error < StandardError; end

  # Base command class for all commands in the system
  class Command < Yousty::Eventsourcing::Command; end

  # Base event class for all events in the system
  class Event < Yousty::Eventsourcing::Event; end

  # Base command handler class for all command handlers in the system
  class CommandHandler < Yousty::Eventsourcing::Stateless::CommandHandler; end
end
