module Sales
  class GenerateOpportunities
    INACTIVE_AFTER_DAYS = 60

    def self.call(...)
      new(...).call
    end

    def initialize(business:, date: Time.zone.today)
      @business = business
      @date = date.to_date
    end

    def call
      created = []
      created.concat generate_follow_ups
      created.concat generate_inactive_customers
      created.concat generate_waitlist_matches
      created.concat generate_fillable_gaps
      created.concat generate_abandoned_bookings
      created.concat generate_abandoned_booking_intents
      created.concat generate_pack_endings
      created.concat generate_referral_requests
      created.compact
    end

    private
      attr_reader :business, :date

      def generate_follow_ups
        business.appointments.completed.includes(:service, :customer_profile).where.not(customer_profile_id: nil).filter_map do |appointment|
          service = appointment.service
          next unless service.follow_up_enabled? && service.recommended_follow_up_days.to_i.positive?
          next unless (appointment.completed_at || appointment.starts_at) <= service.recommended_follow_up_days.days.ago
          next if future_appointment?(appointment.customer_profile, service)

          create_once(
            customer_profile: appointment.customer_profile,
            service: service,
            appointment: appointment,
            employee_membership: appointment.employee_membership,
            opportunity_type: "follow_up_due",
            title: "#{appointment.customer_name} debería volver",
            body: "#{appointment.customer_name} debería volver por #{service.name}. Última visita: #{CustomerDateFormatter.date_label(appointment.starts_at)}.",
            score: frequent_customer?(appointment.customer_profile, service) ? 80 : 70,
            due_at: Time.current
          )
        end
      end

      def generate_inactive_customers
        business.customer_profiles.includes(:appointments).filter_map do |customer|
          completed = customer.appointments.select(&:completed?)
          next if completed.blank?
          next if customer.appointments.any? { |appointment| appointment.starts_at.future? && !appointment.terminal_status? }

          last_appointment = completed.max_by(&:starts_at)
          next unless last_appointment.starts_at <= INACTIVE_AFTER_DAYS.days.ago

          create_once(
            customer_profile: customer,
            service: last_appointment.service,
            appointment: last_appointment,
            employee_membership: last_appointment.employee_membership,
            opportunity_type: "inactive_customer",
            title: "#{customer.name.presence || customer.phone} no vuelve hace #{days_since(last_appointment.starts_at)} días",
            body: "Último servicio: #{last_appointment.service.name}. Conviene enviar un mensaje simple para reactivar.",
            score: completed.size >= 3 ? 60 : 50,
            due_at: Time.current
          )
        end
      end

      def generate_waitlist_matches
        gaps = fillable_gaps
        business.waitlist_entries.visible.includes(:customer_profile, :service).filter_map do |entry|
          matching_gap = gaps.find { |gap| gap.starts_at.to_date == entry.desired_date && gap.service_suggestions.include?(entry.service) }
          next if matching_gap.blank?

          create_once(
            customer_profile: entry.customer_profile,
            service: entry.service,
            employee_membership: matching_gap.employee_membership,
            opportunity_type: "waitlist_match",
            title: "#{entry.client_name} espera #{entry.service.name}",
            body: "Hay un hueco compatible el #{CustomerDateFormatter.datetime_label(matching_gap.starts_at)}.",
            score: 90,
            due_at: matching_gap.starts_at,
            metadata: { waitlist_entry_id: entry.id, gap_starts_at: matching_gap.starts_at.iso8601 }
          )
        end
      end

      def generate_fillable_gaps
        fillable_gaps.filter_map do |gap|
          suggestion = Gaps::SuggestedCustomers.new(business: business, gap: gap, limit: 1).call.first
          service = suggestion&.service || gap.service_suggestions.first
          next if service.blank?

          create_once(
            customer_profile: suggestion&.customer,
            service: service,
            employee_membership: gap.employee_membership,
            opportunity_type: "fillable_gap",
            title: suggestion.present? ? "Ofrecer hueco a #{suggestion.customer.name.presence || suggestion.customer.phone}" : "#{gap.duration_minutes} min libres a las #{CustomerDateFormatter.time_label(gap.starts_at)}",
            body: suggestion.present? ? "#{suggestion.reason}. Hay #{gap.duration_minutes} min libres para #{service.name} el #{CustomerDateFormatter.datetime_label(gap.starts_at)}." : "Entran: #{gap.service_suggestions.map(&:name).to_sentence(two_words_connector: ' y ', last_word_connector: ' y ')}.",
            score: gap.waitlist_count.to_i.positive? ? 85 : 65,
            due_at: gap.starts_at,
            metadata: { gap_starts_at: gap.starts_at.iso8601, gap_ends_at: gap.ends_at.iso8601 }
          )
        end
      end

      def generate_abandoned_bookings
        business.appointments.awaiting_customer_action.includes(:customer_profile, :service).where("starts_at >= ?", Time.current).filter_map do |appointment|
          next unless appointment.pending_deposit? || appointment.deposit_rejected?
          next unless appointment.updated_at <= 3.hours.ago

          create_once(
            customer_profile: appointment.customer_profile,
            service: appointment.service,
            appointment: appointment,
            employee_membership: appointment.employee_membership,
            opportunity_type: "abandoned_booking",
            title: "#{appointment.customer_name} no completó la seña",
            body: "Tiene un turno de #{appointment.service.name} pendiente de seña.",
            score: 60,
            due_at: Time.current
          )
        end
      end

      def generate_abandoned_booking_intents
        business.booking_intents.recoverable.includes(:customer_profile, :service).where("updated_at <= ?", 30.minutes.ago).filter_map do |intent|
          next if intent.completed?

          create_once(
            customer_profile: intent.customer_profile || business.customer_profiles.find_by(normalized_phone: intent.phone_e164),
            service: intent.service,
            employee_membership: intent.employee_membership,
            opportunity_type: "abandoned_booking",
            title: "#{intent.customer_name} dejó una reserva pendiente",
            body: "Quedó pendiente la reserva de #{intent.service&.name || "un servicio"}. Podés abrir WhatsApp y ayudar a confirmarla.",
            score: 60,
            due_at: Time.current,
            metadata: { booking_intent_id: intent.id, phone_e164: intent.phone_e164, selected_starts_at: intent.selected_starts_at&.iso8601 }
          )
        end
      end

      def generate_pack_endings
        business.customer_packs.ending_soon.includes(:customer_profile, service_pack: :service).filter_map do |customer_pack|
          create_once(
            customer_profile: customer_pack.customer_profile,
            service: customer_pack.service_pack.service,
            opportunity_type: "pack_ending",
            title: "Pack por terminar",
            body: "#{customer_pack.customer_profile.name.presence || customer_pack.customer_profile.phone} tiene #{customer_pack.remaining_sessions} sesión(es) de #{customer_pack.service_pack.name}.",
            score: 70,
            due_at: Time.current,
            metadata: { customer_pack_id: customer_pack.id }
          )
        end
      end

      def generate_referral_requests
        return [] unless business.referrals_enabled?

        business.appointments.completed.includes(:customer_profile, :service).where("completed_at >= ? OR starts_at >= ?", 30.days.ago, 30.days.ago).filter_map do |appointment|
          customer = appointment.customer_profile
          next if customer.blank?
          next if business.referrals.where(referrer_customer: customer).where("created_at >= ?", 90.days.ago).exists?

          create_once(
            customer_profile: customer,
            service: appointment.service,
            appointment: appointment,
            employee_membership: appointment.employee_membership,
            opportunity_type: "referral_request",
            title: "Pedir referida a #{appointment.customer_name}",
            body: "Clienta reciente. Podés invitarla a recomendar #{business.name} a una amiga.",
            score: 35,
            due_at: Time.current
          )
        end
      end

      def create_once(attributes)
        if attributes.dig(:metadata, :booking_intent_id).present?
          return if business.sales_opportunities.open.where(opportunity_type: attributes.fetch(:opportunity_type)).where("metadata ->> 'booking_intent_id' = ?", attributes.dig(:metadata, :booking_intent_id).to_s).exists?
        end

        relation = business.sales_opportunities.open.where(
          opportunity_type: attributes.fetch(:opportunity_type),
          customer_profile_id: attributes[:customer_profile]&.id,
          service_id: attributes[:service]&.id,
          appointment_id: attributes[:appointment]&.id
        )
        relation = relation.where(due_at: attributes[:due_at]) if attributes[:customer_profile].blank? && attributes[:appointment].blank? && attributes[:due_at].present?
        return if relation.exists?

        business.sales_opportunities.create!(attributes)
      end

      def fillable_gaps
        @fillable_gaps ||= Availability::FillableGaps.new(business: business, date: date).call
      end

      def future_appointment?(customer, service)
        business.appointments.active.joins(:service)
          .where(customer_profile: customer)
          .where("appointments.starts_at > ?", Time.current)
          .where("appointments.service_id = :service_id OR services.category = :category", service_id: service.id, category: service.category)
          .exists?
      end

      def frequent_customer?(customer, service)
        business.appointments.completed.where(customer_profile: customer, service: service).count >= 2
      end

      def days_since(time)
        ((Time.current - time) / 1.day).floor
      end
  end
end
