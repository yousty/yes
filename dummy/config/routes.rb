# frozen_string_literal: true

Rails.application.routes.draw do
  mount Yousty::Command::Api::Engine => '/commands'
  mount Yousty::Read::Api::Engine => '/queries'
end
