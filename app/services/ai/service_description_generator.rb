module Ai
  class ServiceDescriptionGenerator
    def initialize(business:, service_name:, category_name:)
      @business = business
      @service_name = service_name.to_s.strip
      @category_name = category_name.to_s.strip
    end

    def call
      raise ArgumentError, "Ingresá el nombre del servicio." if service_name.blank?

      description = GeminiClient.chat_text(
        system: system_prompt,
        messages: [ { role: "user", content: user_prompt } ],
        temperature: 0.75,
        max_tokens: 220,
        feature: "service_description",
        business: business
      )

      normalize(description)
    end

    private
      attr_reader :business, :service_name, :category_name

      def system_prompt
        <<~PROMPT
          Sos copywriter experto en servicios de peluquería canina para negocios de Argentina.
          Escribí en español rioplatense, con tono atractivo, claro y profesional.
          Generá un único párrafo breve para mostrar en una página pública de reservas.
          No uses emojis, hashtags, listas, comillas ni frases genéricas como "descubrí una experiencia única".
          No prometas resultados médicos, permanentes o garantizados. No menciones precios ni duración.
          El texto debe invitar a reservar y sonar natural para tutores de mascotas.
        PROMPT
      end

      def user_prompt
        <<~PROMPT
          Negocio: #{business.name}
          Rubro del negocio: #{business.industry_label.presence || "Peluquería canina"}
          Categoría del servicio: #{category_name.presence || "Servicios para mascotas"}
          Nombre del servicio: #{service_name}

          Generá una descripción entre 260 y 420 caracteres.
        PROMPT
      end

      def normalize(value)
        value.to_s
          .strip
          .delete_prefix('"')
          .delete_suffix('"')
          .gsub(/\s+/, " ")
          .truncate(700, omission: "")
          .presence || raise("Gemini no devolvió una descripción.")
      end
  end
end
