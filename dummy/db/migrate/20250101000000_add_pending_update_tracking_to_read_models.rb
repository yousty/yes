# frozen_string_literal: true

class AddPendingUpdateTrackingToReadModels < ActiveRecord::Migration[7.1]
  def change
    # Add pending_update_since to test_users table
    add_column :test_users, :pending_update_since, :datetime
    add_index :test_users, :id,
              unique: true,
              where: 'pending_update_since IS NOT NULL',
              name: 'idx_test_users_one_pending_per_aggregate'
    add_index :test_users, :pending_update_since,
              where: 'pending_update_since IS NOT NULL',
              name: 'idx_test_users_pending_recovery'

    # Add pending_update_since to shared_profile_read_models table
    add_column :shared_profile_read_models, :pending_update_since, :datetime
    add_index :shared_profile_read_models, :id,
              unique: true,
              where: 'pending_update_since IS NOT NULL',
              name: 'idx_shared_profiles_one_pending_per_aggregate'
    add_index :shared_profile_read_models, :pending_update_since,
              where: 'pending_update_since IS NOT NULL',
              name: 'idx_shared_profiles_pending_recovery'
  end
end