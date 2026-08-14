module PurgesReplacedAttachedBlobs
  extend ActiveSupport::Concern

  class_methods do
    def purge_replaced_attached_blobs_for(*attachment_names)
      before_save do
        attachment_names.each { |attachment_name| remember_replaced_attached_blobs(attachment_name) }
      end

      after_commit :purge_remembered_replaced_attached_blobs
      after_rollback :clear_remembered_replaced_attached_blobs
    end
  end

  private
    def remember_replaced_attached_blobs(attachment_name)
      attachment_name = attachment_name.to_s
      change = attachment_changes[attachment_name]
      return if change.blank?

      removed_blobs = current_attached_blobs(attachment_name) - changed_attached_blobs(change)
      return if removed_blobs.blank?

      remembered_replaced_attached_blobs.concat(removed_blobs)
    end

    def current_attached_blobs(attachment_name)
      reflection = self.class.attachment_reflections[attachment_name]
      return [] if reflection.blank?

      case reflection.macro
      when :has_one_attached
        Array(public_send("#{attachment_name}_attachment")&.blob)
      when :has_many_attached
        public_send("#{attachment_name}_attachments").map(&:blob)
      else
        []
      end.compact
    end

    def changed_attached_blobs(change)
      if change.respond_to?(:blobs)
        Array(change.blobs)
      elsif change.respond_to?(:blob)
        Array(change.blob)
      else
        []
      end.compact
    end

    def remembered_replaced_attached_blobs
      @remembered_replaced_attached_blobs ||= []
    end

    def purge_remembered_replaced_attached_blobs
      remembered_replaced_attached_blobs.uniq.each do |blob|
        Storage::PurgeUnattachedBlob.call(blob)
      end
    ensure
      clear_remembered_replaced_attached_blobs
    end

    def clear_remembered_replaced_attached_blobs
      @remembered_replaced_attached_blobs = []
    end
end
