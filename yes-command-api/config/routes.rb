Yes::Command::Api::Engine.routes.draw do
  post '/', to: 'v1/commands#execute'
end
