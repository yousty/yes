# frozen_string_literal: true

Yes::Read::Api::Engine.routes.draw do
  constraints(Yes::Read::Api::ModelConstraints) do
    get '/:model', to: 'queries#call'
  end
end
