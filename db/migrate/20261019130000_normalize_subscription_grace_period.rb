class NormalizeSubscriptionGracePeriod < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE subscriptions
      SET grace_ends_on = next_due_on + 3
      WHERE next_due_on IS NOT NULL
        AND grace_ends_on = next_due_on + 15
    SQL
  end

  def down
    # A longer grace date may be a manual extension, so the normalization is not reversible safely.
  end
end
