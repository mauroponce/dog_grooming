require "json"
require "net/http"
require "uri"

class ResendDeliveryMethod
  class DeliveryError < StandardError; end

  DEFAULT_ENDPOINT = "https://api.resend.com/emails"
  DEFAULT_FROM = "Cita.pet <notificaciones@cita.pet>"
  RESEND_TEST_DOMAIN_PATTERN = /@resend\.dev(?:\s*>|\z)/i

  def self.configured_from
    resend_from = ENV["RESEND_FROM"].presence
    mail_from = ENV["MAIL_FROM"].presence || DEFAULT_FROM

    return mail_from if production? && resend_test_domain?(resend_from)

    resend_from || mail_from
  end

  def self.resend_test_domain?(value)
    value.to_s.match?(RESEND_TEST_DOMAIN_PATTERN)
  end

  def self.production?
    defined?(Rails) && Rails.env.production?
  end

  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    response = request(mail)
    return response if response.is_a?(Net::HTTPSuccess)

    raise DeliveryError, error_message(response)
  end

  private
    attr_reader :settings

    def request(mail)
      uri = URI.parse(settings.fetch(:endpoint, DEFAULT_ENDPOINT))
      http_request = Net::HTTP::Post.new(uri)
      http_request["Authorization"] = "Bearer #{api_key}"
      http_request["Content-Type"] = "application/json"
      http_request.body = payload_for(mail).to_json

      Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: settings.fetch(:open_timeout, 5),
        read_timeout: settings.fetch(:read_timeout, 10)
      ) do |http|
        http.request(http_request)
      end
    end

    def payload_for(mail)
      payload = {
        from: from_address,
        to: addresses(mail.to),
        subject: mail.subject.to_s
      }

      payload[:html] = html_body(mail) if html_body(mail).present?
      payload[:text] = text_body(mail) if text_body(mail).present?
      payload[:cc] = addresses(mail.cc) if addresses(mail.cc).any?
      payload[:bcc] = addresses(mail.bcc) if addresses(mail.bcc).any?
      payload[:reply_to] = reply_to(mail) if reply_to(mail).present?
      payload
    end

    def api_key
      settings[:api_key].presence || ENV.fetch("RESEND_API_KEY")
    end

    def from_address
      settings[:from].presence || self.class.configured_from
    end

    def error_message(response)
      body = response.body.to_s.squish
      detail = body.present? ? ": #{body.first(500)}" : ""
      "Resend rechazó el email con estado #{response.code}#{detail}"
    end

    def reply_to(mail)
      explicit_reply_to = addresses(mail.reply_to)
      return explicit_reply_to if explicit_reply_to.any?

      original_from = addresses(mail.from)
      return if original_from == [ from_address ]

      original_from
    end

    def addresses(value)
      Array(value).compact_blank
    end

    def html_body(mail)
      if mail.html_part
        mail.html_part.body.decoded
      elsif mail.mime_type == "text/html"
        mail.body.decoded
      end
    end

    def text_body(mail)
      if mail.text_part
        mail.text_part.body.decoded
      elsif mail.mime_type != "text/html"
        mail.body.decoded
      end
    end
end
