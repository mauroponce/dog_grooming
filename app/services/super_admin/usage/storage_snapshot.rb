module SuperAdmin
  module Usage
    class StorageSnapshot
      ServiceRow = Struct.new(:name, :objects, :bytes, keyword_init: true)
      RecordTypeRow = Struct.new(:name, :attachments, :bytes, keyword_init: true)

      def call
        {
          total_objects: total_objects,
          total_bytes: total_bytes,
          unattached_objects: unattached_objects,
          services: service_rows,
          record_types: record_type_rows
        }
      rescue StandardError => error
        Rails.logger.warn("Active Storage usage snapshot failed: #{error.class}: #{error.message}")
        {
          total_objects: 0,
          total_bytes: 0,
          unattached_objects: 0,
          services: [],
          record_types: [],
          error: error.message
        }
      end

      private
        def total_objects
          ActiveStorage::Blob.count
        end

        def total_bytes
          ActiveStorage::Blob.sum(:byte_size).to_i
        end

        def unattached_objects
          ActiveStorage::Blob.left_outer_joins(:attachments).where(active_storage_attachments: { id: nil }).count
        end

        def service_rows
          ActiveStorage::Blob
            .group(:service_name)
            .pluck(:service_name, Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(byte_size), 0)"))
            .map { |name, objects, bytes| ServiceRow.new(name: name, objects: objects.to_i, bytes: bytes.to_i) }
            .sort_by { |row| -row.bytes }
        end

        def record_type_rows
          ActiveStorage::Attachment
            .joins(:blob)
            .group(:record_type)
            .pluck(:record_type, Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(active_storage_blobs.byte_size), 0)"))
            .map { |name, attachments, bytes| RecordTypeRow.new(name: name, attachments: attachments.to_i, bytes: bytes.to_i) }
            .sort_by { |row| -row.bytes }
        end
    end
  end
end
