# frozen_string_literal: true

Rails.application.routes.draw do
  mount Yes::Command::Api::Engine => '/v1/commands'
end
