module FollowUps
  class GenerateService
    def self.call(...)
      new(...).call
    end

    def initialize(business:, now: Time.current)
      @business = business
      @now = now
    end

    def call
      candidates.filter_map { |appointment| create_reminder_for(appointment) }
    end

    private
      attr_reader :business, :now

      def candidates
        business.appointments
          .completed
          .joins(:service)
          .includes(:service, :customer_profile)
          .where.not(customer_profile_id: nil)
          .where(services: { follow_up_enabled: true })
          .references(:services)
          .select { |appointment| due_for_follow_up?(appointment) }
      end

      def due_for_follow_up?(appointment)
        days = appointment.service.recommended_follow_up_days.to_i
        return false unless days.positive?

        completed_at = appointment.completed_at || appointment.starts_at
        completed_at <= days.days.ago
      end

      def create_reminder_for(appointment)
        return if upcoming_for_same_service_or_category?(appointment)
        return if duplicate_pending?(appointment)

        business.customer_reminders.create!(
          customer_profile: appointment.customer_profile,
          service: appointment.service,
          appointment: appointment,
          assigned_to: business.owner,
          reminder_type: "service_follow_up",
          remind_at: now,
          body: "#{appointment.customer_name} debería volver por #{appointment.service.name}. Ya pasaron #{days_since(appointment)} días desde la última visita."
        ).tap do |reminder|
          business.provider_events.create!(
            event_type: "follow_up_suggested",
            title: "Clienta para contactar",
            body: reminder.body,
            metadata: {
              customer_profile_id: appointment.customer_profile_id,
              appointment_id: appointment.id,
              service_id: appointment.service_id,
              reminder_id: reminder.id,
              whatsapp_url: follow_up_url(appointment)
            }
          )
        end
      end

      def upcoming_for_same_service_or_category?(appointment)
        business.appointments
          .active
          .joins(:service)
          .where(customer_profile: appointment.customer_profile)
          .where("appointments.starts_at > ?", now)
          .where("appointments.service_id = :service_id OR services.category = :category", service_id: appointment.service_id, category: appointment.service.category)
          .exists?
      end

      def duplicate_pending?(appointment)
        business.customer_reminders.pending.exists?(
          customer_profile: appointment.customer_profile,
          service: appointment.service,
          reminder_type: "service_follow_up"
        )
      end

      def days_since(appointment)
        (((now - (appointment.completed_at || appointment.starts_at)) / 1.day).floor).clamp(0, 999)
      end

      def follow_up_url(appointment)
        WhatsApp::MessageBuilder.new(
          business: business,
          template_key: "customer_reactivation",
          booking: appointment,
          customer: appointment.customer_profile,
          service: appointment.service,
          professional: appointment.employee_membership
        ).url(phone: appointment.customer_phone)
      end
  end
end
