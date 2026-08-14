module Customers
  class RankingService
    CustomerRow = Struct.new(:customer, :segment, :appointments_count, :estimated_total_cents, :last_appointment_at, :favorite_service, :score, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(business:, limit: 20)
      @business = business
      @limit = limit
    end

    def call
      rows.sort_by { |row| -row.score }.first(limit)
    end

    private
      attr_reader :business, :limit

      def rows
        business.customer_profiles.includes(:appointments).filter_map do |customer|
          appointments = customer.appointments.select { |appointment| appointment.business_id == business.id }
          next if appointments.blank?

          completed = appointments.select(&:completed?)
          total_cents = appointments.sum { |appointment| appointment.final_price_cents.to_i.positive? ? appointment.final_price_cents : appointment.service&.price_cents.to_i }
          last_appointment = appointments.max_by(&:starts_at)
          favorite_service = appointments.group_by(&:service).max_by { |_service, items| items.size }&.first

          CustomerRow.new(
            customer: customer,
            segment: segment_for(customer, appointments, completed, total_cents, last_appointment),
            appointments_count: appointments.size,
            estimated_total_cents: total_cents,
            last_appointment_at: last_appointment&.starts_at,
            favorite_service: favorite_service,
            score: score_for(customer, appointments, completed, total_cents, last_appointment)
          )
        end
      end

      def segment_for(customer, appointments, completed, total_cents, last_appointment)
        return "Con packs activos" if business.customer_packs.active.exists?(customer_profile: customer)
        return "No-shows frecuentes" if customer.no_show_count.to_i >= 2
        return "Inactiva importante" if last_appointment&.starts_at.present? && last_appointment.starts_at < 60.days.ago && total_cents >= 100_000_00
        return "Mayor ticket" if total_cents >= 150_000_00
        return "Frecuente" if completed.size >= 3 || appointments.size >= 4
        return "Con seguimiento pendiente" if business.customer_reminders.pending.exists?(customer_profile: customer)

        "Activa"
      end

      def score_for(customer, appointments, completed, total_cents, last_appointment)
        score = appointments.size * 8
        score += completed.size * 10
        score += [ total_cents / 10_000_00, 30 ].min
        score += 20 if business.customer_packs.active.exists?(customer_profile: customer)
        score += 15 if business.customer_reminders.pending.exists?(customer_profile: customer)
        score -= 10 if customer.no_show_count.to_i.positive?
        score -= 8 if last_appointment&.starts_at.present? && last_appointment.starts_at < 90.days.ago
        score
      end
  end
end
