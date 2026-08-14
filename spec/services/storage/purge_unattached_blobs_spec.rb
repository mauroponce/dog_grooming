require "rails_helper"

RSpec.describe Storage::PurgeUnattachedBlobs do
  it "purges only old unattached blobs across storage services" do
    old_primary_blob = create_blob(filename: "old-primary.txt")
    old_primary_blob.update!(created_at: 2.days.ago)
    old_service_image_blob = create_blob(filename: "old-service-image.txt", service_name: "service_images")
    old_service_image_blob.update!(created_at: 2.days.ago)
    recent_blob = create_blob(filename: "recent.txt")
    recent_blob.update!(created_at: 2.hours.ago)
    attached_blob = attach_profile_photo
    attached_blob.update!(created_at: 2.days.ago)

    result = described_class.new(older_than: 24.hours, dry_run: false).call

    expect(result).to be_ok
    expect(result.matched_count).to eq(2)
    expect(result.purged_count).to eq(2)
    expect(result.services.fetch("test").objects).to eq(1)
    expect(result.services.fetch("service_images").objects).to eq(1)
    expect(ActiveStorage::Blob.exists?(old_primary_blob.id)).to be(false)
    expect(ActiveStorage::Blob.exists?(old_service_image_blob.id)).to be(false)
    expect(ActiveStorage::Blob.exists?(recent_blob.id)).to be(true)
    expect(ActiveStorage::Blob.exists?(attached_blob.id)).to be(true)
  end

  it "does not delete matching blobs in dry-run mode" do
    blob = create_blob(filename: "dry-run.txt")
    blob.update!(created_at: 2.days.ago)

    result = described_class.new(older_than: 24.hours, dry_run: true).call

    expect(result).to be_ok
    expect(result.matched_count).to eq(1)
    expect(result.purged_count).to eq(0)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
  end

  private
    def create_blob(filename:, service_name: nil)
      attributes = {
        io: StringIO.new("archivo"),
        filename: filename,
        content_type: "text/plain"
      }
      attributes[:service_name] = service_name if service_name.present?

      ActiveStorage::Blob.create_and_upload!(**attributes)
    end

    def attach_profile_photo
      user = User.create!(
        email_address: "user-#{SecureRandom.hex(6)}@example.com",
        password: "password123"
      )

      user.profile_photo.attach(
        io: StringIO.new("photo"),
        filename: "profile.png",
        content_type: "image/png"
      )
      user.profile_photo.blob
    end
end
