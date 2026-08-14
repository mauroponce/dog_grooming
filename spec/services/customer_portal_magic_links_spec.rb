require "rails_helper"

RSpec.describe "Customer portal magic links" do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  describe CustomerPortal::MagicLinks::CreateService do
    it "creates a digest-only token and sends the raw token by mail" do
      business = create_business
      create_customer(business, email: " Julieta@Example.com ")
      delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      raw_token = nil

      expect(CustomerPortalMailer).to receive(:magic_link) do |_record, token|
        raw_token = token
        delivery
      end

      result = described_class.call(business: business, email: "julieta@example.com")
      token_record = CustomerPortalAccessToken.last

      expect(result.sent).to eq(true)
      expect(token_record.email).to eq("julieta@example.com")
      expect(token_record.token_digest).to eq(CustomerPortalAccessToken.digest(raw_token))
      expect(token_record.token_digest).not_to eq(raw_token)
      expect(token_record.expires_at).to be_within(2.seconds).of(30.minutes.from_now)
    end

    it "does not reveal whether an email has customers" do
      business = create_business

      expect(CustomerPortalMailer).not_to receive(:magic_link)
      result = described_class.call(business: business, email: "unknown@example.com")

      expect(result.sent).to eq(false)
      expect(CustomerPortalAccessToken.count).to eq(0)
    end

    it "throttles repeated requests for the same business and email" do
      business = create_business
      customer = create_customer(business, email: "julieta@example.com")
      business.customer_portal_access_tokens.create!(
        customer_profile: customer,
        email: "julieta@example.com",
        token_digest: CustomerPortalAccessToken.digest("already-sent"),
        purpose: "customer_portal_login",
        expires_at: 30.minutes.from_now,
        last_sent_at: 20.seconds.ago
      )

      expect(CustomerPortalMailer).not_to receive(:magic_link)
      result = described_class.call(business: business, email: "julieta@example.com")

      expect(result.throttled).to eq(true)
      expect(CustomerPortalAccessToken.count).to eq(1)
    end

    it "does not send a portal link by WhatsApp when a phone is provided" do
      business = create_business
      customer = create_customer(business, email: "julieta@example.com")
      whatsapp_client = instance_double(
        WhatsApp::EvolutionClient,
        configured?: true,
        send_text: { success: true, body: { "key" => { "id" => "whatsapp-123" } } }
      )

      result = described_class.call(
        business: business,
        contact: "+54 9 11 1111-1111",
        whatsapp_client: whatsapp_client
      )

      expect(result.sent).to eq(false)
      expect(result.channel).to eq("email")
      expect(whatsapp_client).not_to have_received(:send_text)
      expect(NotificationDelivery.where(channel: "whatsapp_evolution")).to be_empty
    end
  end

  describe CustomerPortal::MagicLinks::ConsumeService do
    it "consumes a valid token only once" do
      business = create_business
      customer = create_customer(business, email: "julieta@example.com")
      raw_token = SecureRandom.urlsafe_base64(32)
      token_record = business.customer_portal_access_tokens.create!(
        customer_profile: customer,
        email: "julieta@example.com",
        token_digest: CustomerPortalAccessToken.digest(raw_token),
        purpose: "customer_portal_login",
        expires_at: 30.minutes.from_now
      )

      result = described_class.call(business: business, token: raw_token)

      expect(result.email).to eq("julieta@example.com")
      expect(result.customer_ids).to eq([ customer.id ])
      expect(token_record.reload.consumed_at).to be_present
      expect { described_class.call(business: business, token: raw_token) }.to raise_error(CustomerPortal::MagicLinks::ConsumeService::InvalidToken)
    end

    it "rejects expired and cross-business tokens" do
      business = create_business
      other_business = create_business
      customer = create_customer(business, email: "julieta@example.com")
      raw_token = SecureRandom.urlsafe_base64(32)
      business.customer_portal_access_tokens.create!(
        customer_profile: customer,
        email: "julieta@example.com",
        token_digest: CustomerPortalAccessToken.digest(raw_token),
        purpose: "customer_portal_login",
        expires_at: 1.minute.ago
      )

      expect { described_class.call(business: business, token: raw_token) }.to raise_error(CustomerPortal::MagicLinks::ConsumeService::InvalidToken)
      expect { described_class.call(business: other_business, token: raw_token) }.to raise_error(CustomerPortal::MagicLinks::ConsumeService::InvalidToken)
    end
  end

  def create_business
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    Business.create!(
      owner: owner,
      name: "Estetica Demo",
      slug: "estetica-demo-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 2222-2222",
      onboarding_completed_at: Time.current
    )
  end

  def create_customer(business, email:)
    business.customer_profiles.create!(
      name: "Julieta Perez",
      phone: "+54 9 11 1111-1111",
      email: email
    )
  end
end
