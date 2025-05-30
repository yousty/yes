# frozen_string_literal: true

# Dummy read model for testing SharedReadModelRebuilder
class SharedProfileReadModel < Yes::Core::ApplicationRecord
  self.table_name = 'shared_profile_read_models'

  # Method for authorization attributes if needed
  def auth_attributes
    { profile_id: id || '', email: email || '' }
  end

  # Full name helper
  def full_name
    "#{first_name} #{last_name}".strip
  end

  # Complete address helper
  def full_address
    [address, city, postal_code, country].compact.join(', ')
  end
end
