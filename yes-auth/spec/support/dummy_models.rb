# frozen_string_literal: true

# Dummy ActiveRecord models used by specs as resource targets.
# These simulate external domain models (companies, apprenticeships, locations)
# that are referenced by resource access records.
class Company < ActiveRecord::Base
  self.table_name = 'companies'
end

class Apprenticeship < ActiveRecord::Base
  self.table_name = 'apprenticeships'
end

class Location < ActiveRecord::Base
  self.table_name = 'locations'
end
