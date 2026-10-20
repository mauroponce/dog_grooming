class TrackBillingReminderJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :billing_reminders, :active_job_id, :string
    add_index :billing_reminders, :active_job_id
  end
end
