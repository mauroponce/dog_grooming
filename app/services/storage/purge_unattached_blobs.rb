module Storage
  class PurgeUnattachedBlobs
    DEFAULT_OLDER_THAN = 24.hours
    DEFAULT_BATCH_SIZE = 100

    ServiceStat = Struct.new(:name, :objects, :bytes, keyword_init: true)
    Error = Struct.new(:blob_id, :key, :service_name, :message, keyword_init: true)
    Result = Struct.new(
      :matched_count,
      :matched_bytes,
      :purged_count,
      :dry_run,
      :cutoff,
      :services,
      :errors,
      keyword_init: true
    ) do
      def ok?
        errors.blank?
      end
    end

    def initialize(older_than: DEFAULT_OLDER_THAN, dry_run: true, limit: nil, batch_size: DEFAULT_BATCH_SIZE)
      @cutoff = cutoff_for(older_than)
      @dry_run = ActiveModel::Type::Boolean.new.cast(dry_run)
      @limit = positive_integer(limit)
      @batch_size = positive_integer(batch_size) || DEFAULT_BATCH_SIZE
    end

    def call
      services = Hash.new { |hash, name| hash[name] = ServiceStat.new(name: name, objects: 0, bytes: 0) }
      errors = []
      matched_count = 0
      matched_bytes = 0
      purged_count = 0

      blobs_scope.find_each(batch_size: batch_size) do |blob|
        service_name = blob.service_name.to_s
        byte_size = blob.byte_size.to_i

        matched_count += 1
        matched_bytes += byte_size
        services[service_name].objects += 1
        services[service_name].bytes += byte_size

        next if dry_run

        begin
          blob.reload
          next if blob.attachments.exists?

          blob.purge
          purged_count += 1
        rescue ActiveRecord::RecordNotFound
          next
        rescue StandardError => error
          errors << Error.new(
            blob_id: blob.id,
            key: blob.key,
            service_name: service_name,
            message: "#{error.class}: #{error.message}"
          )
        end
      end

      Result.new(
        matched_count: matched_count,
        matched_bytes: matched_bytes,
        purged_count: purged_count,
        dry_run: dry_run,
        cutoff: cutoff,
        services: services,
        errors: errors
      )
    end

    private
      attr_reader :cutoff, :dry_run, :limit, :batch_size

      def blobs_scope
        scope = ActiveStorage::Blob
          .unattached
          .where(ActiveStorage::Blob.arel_table[:created_at].lt(cutoff))
          .reorder(:id)

        limit.present? ? scope.limit(limit) : scope
      end

      def cutoff_for(value)
        case value
        when ActiveSupport::Duration
          value.ago
        when Time, DateTime
          value.to_time
        else
          value.to_i.seconds.ago
        end
      end

      def positive_integer(value)
        integer = value.to_i if value.present?
        integer if integer&.positive?
      end
  end
end
