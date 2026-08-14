class PurgeBusinessPublicImages < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  ATTACHMENT_NAMES = %w[public_cover_photo public_gallery_images portfolio_images].freeze

  def up
    say_with_time "Purging business public images" do
      attachments = ActiveStorage::Attachment.where(record_type: "Business", name: ATTACHMENT_NAMES)
      count = attachments.count
      attachments.find_each(&:purge)
      count
    end
  end

  def down
    # No-op: purged files and Active Storage rows cannot be restored.
  end
end
