# frozen_string_literal: true

Yousty::Read::Api::Engine.routes.draw do
  constraints(Yousty::Read::Api::ModelConstraints) do
    get '/:model', to: 'queries#call'
  end
end
