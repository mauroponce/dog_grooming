class NormalizeWaitlistStatuses < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE waitlist_entries
      SET status = CASE status
        WHEN 'pending' THEN 'waiting'
        WHEN 'notified' THEN 'offered'
        WHEN 'completed' THEN 'booked'
        ELSE status
      END
      WHERE status IN ('pending', 'notified', 'completed')
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE waitlist_entries
      SET status = CASE status
        WHEN 'waiting' THEN 'pending'
        WHEN 'offered' THEN 'notified'
        WHEN 'booked' THEN 'completed'
        ELSE status
      END
      WHERE status IN ('waiting', 'offered', 'booked')
    SQL
  end
end
