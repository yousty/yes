# frozen_string_literal: true

class AddPendingUpdateTrackingToReadModels < ActiveRecord::Migration[7.1]
  def up
    # Create the trigger function to prevent concurrent pending updates
    execute <<-SQL
      CREATE OR REPLACE FUNCTION prevent_concurrent_pending_update()
      RETURNS TRIGGER AS $$
      BEGIN
        -- If trying to set pending_update_since when it's already set
        IF NEW.pending_update_since IS NOT NULL AND 
           OLD.pending_update_since IS NOT NULL AND
           NEW.pending_update_since != OLD.pending_update_since THEN
          RAISE EXCEPTION 'Concurrent pending update not allowed for record %', NEW.id
            USING ERRCODE = 'unique_violation';
        END IF;
        
        -- Allow clearing pending_update_since (setting to NULL)
        -- Allow initial setting when OLD value is NULL
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Add pending_update_since to test_users table
    add_column :test_users, :pending_update_since, :datetime
    
    # Create trigger for test_users
    execute <<-SQL
      CREATE TRIGGER trg_test_users_prevent_concurrent_pending
        BEFORE UPDATE ON test_users
        FOR EACH ROW
        EXECUTE FUNCTION prevent_concurrent_pending_update();
    SQL
    
    # Add recovery index for test_users
    add_index :test_users, :pending_update_since,
              where: 'pending_update_since IS NOT NULL',
              name: 'idx_test_users_pending_recovery'

    # Add pending_update_since to shared_profile_read_models table
    add_column :shared_profile_read_models, :pending_update_since, :datetime
    
    # Create trigger for shared_profile_read_models
    execute <<-SQL
      CREATE TRIGGER trg_shared_profiles_prevent_concurrent_pending
        BEFORE UPDATE ON shared_profile_read_models
        FOR EACH ROW
        EXECUTE FUNCTION prevent_concurrent_pending_update();
    SQL
    
    # Add recovery index for shared_profile_read_models
    add_index :shared_profile_read_models, :pending_update_since,
              where: 'pending_update_since IS NOT NULL',
              name: 'idx_shared_profiles_pending_recovery'
  end

  def down
    # Remove triggers
    execute 'DROP TRIGGER IF EXISTS trg_test_users_prevent_concurrent_pending ON test_users;'
    execute 'DROP TRIGGER IF EXISTS trg_shared_profiles_prevent_concurrent_pending ON shared_profile_read_models;'
    
    # Remove the trigger function
    execute 'DROP FUNCTION IF EXISTS prevent_concurrent_pending_update();'
    
    # Remove indexes
    remove_index :test_users, name: 'idx_test_users_pending_recovery'
    remove_index :shared_profile_read_models, name: 'idx_shared_profiles_pending_recovery'
    
    # Remove columns
    remove_column :test_users, :pending_update_since
    remove_column :shared_profile_read_models, :pending_update_since
  end
end