module Admin
  class UpdatePaymentPreferences
    def self.call(business, params)
      new(business, params).call
    end

    def initialize(business, params)
      @business = business
      @params = params.to_h
    end

    def call
      business.update!(preferences: business.preferences.to_h.merge(normalized_preferences))
      business
    end

    private
      attr_reader :business, :params

      def normalized_preferences
        enabled_payment_methods = Business.normalize_enabled_payment_methods(params["enabled_payment_methods"] || params[:enabled_payment_methods])

        {
          "enabled_payment_methods" => enabled_payment_methods.presence || [ "mercado_pago" ]
        }
      end
  end
end
