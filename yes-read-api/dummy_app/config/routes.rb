# frozen_string_literal: true

Rails.application.routes.draw do
  mount Yes::Read::Api::Engine => '/queries'
end
