module BookingIntents
  class ExpireService
    def self.call(...)
      new(...).call
    end

    def initialize(business: nil, now: Time.current)
      @business = business
      @now = now
    end

    def call
      scope.find_each.filter_map do |intent|
        expire_intent(intent)
      end
    end

    private
      attr_reader :business, :now

      def scope
        relation = BookingIntent.expired_for_recovery.where("created_at >= ?", 7.days.ago)
        relation = relation.where(business:) if business.present?
        relation.includes(:business, :service, :customer_profile)
      end

      def expire_intent(intent)
        intent.update!(status: intent.pending_deposit? ? "pending_deposit" : "abandoned")
        create_opportunity(intent)
      end

      def create_opportunity(intent)
        return if intent.phone_e164.blank?
        return if intent.business.sales_opportunities.open.where(opportunity_type: "abandoned_booking").where("metadata ->> 'booking_intent_id' = ?", intent.id.to_s).exists?

        customer = intent.customer_profile || find_customer(intent)
        intent.business.sales_opportunities.create!(
          customer_profile: customer,
          service: intent.service,
          employee_membership: intent.employee_membership,
          opportunity_type: "abandoned_booking",
          title: "#{intent.customer_name} dejó una reserva pendiente",
          body: "Quedó pendiente la reserva de #{intent.service&.name || "un servicio"}. Podés revisarla y contactar a la persona manualmente.",
          score: 60,
          due_at: now,
          metadata: { booking_intent_id: intent.id, selected_starts_at: intent.selected_starts_at&.iso8601, phone_e164: intent.phone_e164 }
        )
      end

      def find_customer(intent)
        intent.business.customer_profiles.find_by(normalized_phone: intent.phone_e164)
      end
  end
end
