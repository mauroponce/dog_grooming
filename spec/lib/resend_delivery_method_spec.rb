require "rails_helper"

RSpec.describe ResendDeliveryMethod do
  around do |example|
    original_resend_from = ENV["RESEND_FROM"]
    original_mail_from = ENV["MAIL_FROM"]
    example.run
  ensure
    ENV["RESEND_FROM"] = original_resend_from
    ENV["MAIL_FROM"] = original_mail_from
  end

  describe ".configured_from" do
    it "ignores Resend's test sender in production and uses MAIL_FROM" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      ENV["RESEND_FROM"] = "onboarding@resend.dev"
      ENV["MAIL_FROM"] = "Cita.pet <no-reply@cita.pet>"

      expect(described_class.configured_from).to eq("Cita.pet <no-reply@cita.pet>")
    end

    it "keeps a verified RESEND_FROM sender in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      ENV["RESEND_FROM"] = "Cita.pet <notificaciones@cita.pet>"
      ENV["MAIL_FROM"] = "Cita.pet <no-reply@cita.pet>"

      expect(described_class.configured_from).to eq("Cita.pet <notificaciones@cita.pet>")
    end
  end

  describe "#deliver!" do
    it "includes Resend's response body in delivery errors" do
      response = Class.new do
        def code = "403"
        def body = '{"message":"The from address is not verified"}'
        def is_a?(klass) = false
      end.new
      delivery_method = described_class.new(api_key: "test", from: "Cita.pet <no-reply@cita.pet>")
      mail = Mail.new(to: "user@example.com", subject: "Test", body: "Body")

      allow(delivery_method).to receive(:request).and_return(response)

      expect { delivery_method.deliver!(mail) }
        .to raise_error(described_class::DeliveryError, /The from address is not verified/)
    end
  end
end
