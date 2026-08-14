require "securerandom"

module Storage
  class ObjectKeyBuilder
    def self.deposit_receipt(appointment, filename:)
      new(
        business: appointment.business,
        folder: "comprobantes",
        record: appointment,
        filename: filename,
        timestamp: appointment.starts_at
      ).call
    end

    def self.subscription_payment_proof(proof, filename:)
      new(
        business: proof.business,
        folder: "suscripcion/comprobantes",
        record: proof,
        filename: filename,
        timestamp: proof.uploaded_at || Time.current
      ).call
    end

    def self.business_logo(business, filename:)
      new(
        business: business,
        folder: "imagenes/logos",
        record: business,
        filename: filename
      ).call
    end

    def self.post_appointment_photo(appointment, filename:)
      new(
        business: appointment.business,
        folder: "post-turno",
        record: appointment,
        filename: filename,
        timestamp: appointment.starts_at
      ).call
    end

    def self.service_cover(service, filename:)
      new(
        business: service.business,
        folder: "imagenes/servicios",
        record: service,
        filename: filename
      ).call
    end

    def self.service_category_cover(category, filename:)
      new(
        business: category.business,
        folder: "imagenes/categorias",
        record: category,
        filename: filename
      ).call
    end

    def self.service_image(service, filename:)
      new(
        business: service.business,
        folder: "imagenes/servicios/galeria",
        record: service,
        filename: filename
      ).call
    end

    def self.customer_photo(customer, filename:)
      new(
        business: customer.business,
        folder: "imagenes/clientes",
        record: customer,
        filename: filename
      ).call
    end

    def initialize(business:, folder:, record:, filename:, timestamp: Time.current)
      @business = business
      @folder = folder
      @record = record
      @filename = filename.to_s
      @timestamp = timestamp || Time.current
    end

    def call
      [
        business_segment,
        folder,
        date_segment,
        record_segment,
        file_segment
      ].join("/")
    end

    private
      attr_reader :business, :folder, :record, :filename, :timestamp

      def business_segment
        segment(business.slug.presence || business.id)
      end

      def date_segment
        timestamp.in_time_zone.strftime("%Y-%m")
      end

      def record_segment
        "#{record.model_name.singular}-#{record.id || SecureRandom.hex(8)}"
      end

      def file_segment
        [
          timestamp.in_time_zone.strftime("%Y%m%d%H%M%S"),
          original_name_segment,
          SecureRandom.hex(8)
        ].compact_blank.join("-") + extension
      end

      def original_name_segment
        basename = File.basename(filename, ".*")
        segment(basename).presence
      end

      def extension
        ext = File.extname(filename).downcase
        ext.match?(/\A\.[a-z0-9]{1,10}\z/) ? ext : ""
      end

      def segment(value)
        I18n.transliterate(value.to_s)
          .downcase
          .gsub(/[^a-z0-9_-]+/, "-")
          .gsub(/\A-+|-+\z/, "")
          .presence || "sin-identificar"
      end
  end
end
