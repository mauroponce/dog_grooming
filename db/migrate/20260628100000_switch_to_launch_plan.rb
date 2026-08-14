class SwitchToLaunchPlan < ActiveRecord::Migration[8.1]
  def up
    add_column :businesses, :trial_started_at, :datetime
    add_column :businesses, :setup_status, :string, null: false, default: "not_started"
    change_column_default :businesses, :plan, from: "basic", to: "launch"

    now = Time.current
    execute <<~SQL.squish
      UPDATE businesses
      SET plan = 'launch',
          trial_started_at = COALESCE(trial_started_at, created_at, '#{now.to_fs(:db)}')
    SQL
    execute "UPDATE businesses SET trial_ends_at = trial_started_at + INTERVAL '14 days'"
    change_column_null :businesses, :trial_started_at, false
  end

  def down
    change_column_null :businesses, :trial_started_at, true
    execute "UPDATE businesses SET plan = 'basic' WHERE plan = 'launch'"
    change_column_default :businesses, :plan, from: "launch", to: "basic"
    remove_column :businesses, :setup_status
    remove_column :businesses, :trial_started_at
  end
end
