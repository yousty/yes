# frozen_string_literal: true

module Yes
  module Auth
    # Auto-configures yes-core's Cerbos principal data builders when yes-auth is loaded.
    class Railtie < Rails::Railtie
      initializer 'yes_auth.configure_cerbos' do
        Yes::Core.configure do |config|
          config.cerbos_principal_data_builder ||=
            Yes::Auth::Cerbos::WriteResourceAccess::PrincipalData.method(:call)
          config.cerbos_read_principal_data_builder ||=
            Yes::Auth::Cerbos::ReadResourceAccess::PrincipalData.method(:call)
        end
      end
    end
  end
end
