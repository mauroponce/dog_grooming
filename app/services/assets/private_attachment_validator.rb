module Assets
  class PrivateAttachmentValidator
    DEFAULT_IMAGE_TYPES = %w[image/png image/jpeg image/jpg image/webp image/heic image/heif].freeze

    def self.validate!(upload, content_types: DEFAULT_IMAGE_TYPES, max_size: 5.megabytes)
      new(upload:, content_types:, max_size:).validate!
    end

    def initialize(upload:, content_types:, max_size:)
      @upload = upload
      @content_types = content_types
      @max_size = max_size
    end

    def validate!
      raise ActiveRecord::RecordInvalid.new(invalid_record("debe ser un archivo permitido")) unless content_type.in?(content_types)
      raise ActiveRecord::RecordInvalid.new(invalid_record("no puede superar #{max_size / 1.megabyte} MB")) if size > max_size

      true
    end

    private
      attr_reader :upload, :content_types, :max_size

      def content_type
        upload.respond_to?(:content_type) ? upload.content_type.to_s : ""
      end

      def size
        upload.respond_to?(:size) ? upload.size.to_i : upload.try(:tempfile).try(:size).to_i
      end

      def invalid_record(message)
        record = BookingAttachment.new
        record.errors.add(:base, message)
        record
      end
  end
end
