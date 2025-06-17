# frozen_string_literal: true

Rails.application.routes.draw do
  mount Yes::Command::Api::Engine => '/commands'
  mount Yes::Read::Api::Engine => '/queries'

  require 'pg_eventstore/web'
  mount PgEventstore::Web::Application => 'pg_eventstore'
end
