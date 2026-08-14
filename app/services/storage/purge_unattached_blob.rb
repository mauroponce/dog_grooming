module Storage
  class PurgeUnattachedBlob
    def self.call(blob)
      new(blob).call
    end

    def initialize(blob)
      @blob = blob
    end

    def call
      return if blob.blank? || blob.id.blank?

      reloaded_blob = ActiveStorage::Blob.find_by(id: blob.id)
      return if reloaded_blob.blank? || reloaded_blob.attachments.exists?

      reloaded_blob.purge_later
    end

    private
      attr_reader :blob
  end
end
