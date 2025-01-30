# frozen_string_literal: true

module Yes
  module Core
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
