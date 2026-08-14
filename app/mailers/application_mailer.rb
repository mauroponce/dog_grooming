class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "Dog Grooming <notificaciones@dog-grooming.example.com>"),
    reply_to: -> { ENV["MAIL_REPLY_TO"].presence }
  layout "mailer"

  after_deliver :log_email_delivery

  private
    def app_host
      options = mailer_url_options
      host = options.fetch(:host)
      port = options[:port]

      port.present? ? "#{host}:#{port}" : host
    end

    def app_protocol
      mailer_url_options.fetch(:protocol, Rails.env.production? ? "https" : "http").to_s.delete_suffix("://")
    end

    def mailer_url_options
      return { host: "localhost", port: 3000, protocol: "http" } if Rails.env.test?

      Rails.application.config.action_mailer.default_url_options.symbolize_keys
    end

    def log_email_delivery
      return unless defined?(EmailDeliveryLog)

      recipients = Array(message.to).compact_blank
      recipients.each do |recipient|
        EmailDeliveryLog.create!(
          business: instance_variable_get(:@business),
          recipient: recipient,
          mailer: self.class.name,
          action: action_name,
          subject: message.subject.to_s,
          provider: Rails.env.production? ? "resend" : "local",
          status: "sent",
          sent_at: Time.current,
          metadata: { message_id: message.message_id }
        )
      end
    rescue StandardError => error
      Rails.logger.warn("EmailDeliveryLog skipped for #{self.class.name}##{action_name}: #{error.class} #{error.message}")
    end
end
