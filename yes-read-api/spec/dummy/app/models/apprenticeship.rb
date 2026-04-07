# frozen_string_literal: true

class Apprenticeship < ApplicationRecord
  belongs_to :company, optional: true

  scope :by_id, ->(ids) { where(id: ids) }
  scope :dropout_enabled, -> { where(dropout_enabled: true) }
  scope :by_company_id, ->(ids) { where(company_id: ids) }
end
