module Storage
  class UploadAttachable
    def self.build(upload, key:)
      new(upload, key: key).build
    end

    def initialize(upload, key:)
      @upload = upload
      @key = key
    end

    def build
      io.rewind if io.respond_to?(:rewind)

      {
        io: io,
        filename: filename,
        content_type: content_type,
        key: key
      }.compact
    end

    private
      attr_reader :upload, :key

      def io
        @io ||= upload.respond_to?(:tempfile) ? upload.tempfile : upload
      end

      def filename
        if upload.respond_to?(:original_filename)
          upload.original_filename
        elsif upload.respond_to?(:path)
          File.basename(upload.path)
        else
          "archivo"
        end
      end

      def content_type
        upload.content_type if upload.respond_to?(:content_type)
      end
  end
end
