# frozen_string_literal: true

Rails.application.routes.draw do
  mount Yes::Command::Api::Engine => '/commands'
  mount Yousty::Read::Api::Engine => '/queries'
end
