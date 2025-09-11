# frozen_string_literal: true

require 'yousty/eventsourcing'
require 'zeitwerk'
require 'yousty/api' # for serializers

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
