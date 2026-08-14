module CustomerReminders
  class CreateService
    def initialize(customer:, business:, actor:, attributes:)
      @customer = customer
      @business = business
      @actor = actor
      @attributes = attributes
    end

    def call
      reminder = customer.customer_reminders.create!(
        business: business,
        assigned_to: assignee,
        body: attributes.fetch(:body).to_s.strip,
        remind_at: parsed_remind_at
      )

      notify_if_due(reminder)
      reminder
    end

    private
      attr_reader :customer, :business, :actor, :attributes

      def assignee
        return actor if attributes[:assigned_to_id].blank?

        users_for_business.find(attributes[:assigned_to_id])
      end

      def users_for_business
        User.where(id: [ business.owner_id ] + business.employee_memberships.active.where.not(user_id: nil).pluck(:user_id))
      end

      def parsed_remind_at
        value = attributes.fetch(:remind_at)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def notify_if_due(reminder)
        return unless reminder.due?

        business.provider_events.create!(
          user: actor,
          event_type: "customer_reminder_due",
          title: "Recordatorio de cliente",
          body: "#{customer.name.presence || customer.phone}: #{reminder.body}",
          metadata: {
            customer_profile_id: customer.id,
            reminder_id: reminder.id,
            action_url: Rails.application.routes.url_helpers.admin_customer_profiles_url(
              customer_id: customer.id,
              host: app_host,
              protocol: app_protocol
            )
          }
        )
        CustomerReminderMailer.due(reminder).deliver_later if reminder.assigned_to&.email_address.present?
      end

      def app_host
        AppUrl.host
      end

      def app_protocol
        AppUrl.protocol
      end
  end
end
