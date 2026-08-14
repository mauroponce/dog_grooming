class AddRecurrenceToAvailabilityBlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :availability_blocks, :description, :text
    add_column :availability_blocks, :online_booking_allowed, :boolean, null: false, default: false
    add_column :availability_blocks, :recurrence, :string, null: false, default: "none"
    add_column :availability_blocks, :recurrence_ends_on, :date

    add_index :availability_blocks, [ :business_id, :recurrence, :recurrence_ends_on ], name: "idx_availability_blocks_recurrence"
  end
end
