# frozen_string_literal: true

class Apprenticeship < ApplicationRecord
  belongs_to :company, optional: true

  scope :by_id, ->(ids) { where(id: ids) }
  scope :dropout_enabled, -> { where(dropout_enabled: true) }
end
