# frozen_string_literal: true

Rails.application.routes.draw do
  mount Yes::Read::Api::Engine => '/queries'
  get '/shop_search/:model', to: 'shop_search#search'
  post '/shop_search/:model', to: 'shop_search#search'
  get '/shop_export/:model', to: 'shop_export#search'
end
