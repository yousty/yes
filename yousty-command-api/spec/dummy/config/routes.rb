Rails.application.routes.draw do
  mount Yousty::Command::Api::Engine => '/v1/commands'
end
