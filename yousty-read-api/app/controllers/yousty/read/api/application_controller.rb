#frozen_string_literal: true

module Yousty
  module Read
    module Api
      class ApplicationController < ActionController::API
        before_action :set_locale

        def set_locale
          I18n.locale = params[:locale] || I18n.default_locale
        end

        def append_info_to_payload(payload)
          super
          payload[:request_id] = request.uuid
          payload[:request_headers] = request.env.select do |k, _v|
            k.match(/\A(HTTP.*|CONTENT.*|REMOTE.*|REQUEST.*|AUTHORIZATION.*|SCRIPT.*|SERVER.*)/)
          end
        end
      end
    end
  end
end
