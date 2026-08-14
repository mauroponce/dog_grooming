module WhatsApp
  class UrlBuilder
    MissingPhone = Class.new(StandardError)

    def self.call(phone:, text:)
      new(phone:, text:).call
    end

    def initialize(phone:, text:)
      @phone = phone
      @text = text
    end

    def call
      digits = PhoneNumber.normalize(phone).delete_prefix("+")
      raise MissingPhone, "No hay WhatsApp válido para esta clienta." if digits.blank?

      query = text.present? ? "?text=#{ERB::Util.url_encode(text)}" : ""
      "https://wa.me/#{digits}#{query}"
    end

    private
      attr_reader :phone, :text
  end
end
