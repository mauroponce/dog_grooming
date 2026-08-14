require "rails_helper"

RSpec.describe Service do
  describe ".publicly_bookable" do
    it "includes complete public services without a price" do
      business = create_business
      service = business.services.create!(
        name: "Consulta inicial",
        category: "General",
        description: "Evaluación inicial para definir el tratamiento.",
        duration_minutes: 30,
        price_cents: 0,
        active: true,
        public_visible: true,
        visibility_mode: "public"
      )

      expect(described_class.publicly_bookable).to include(service)
    end

    it "does not require the optional description" do
      business = create_business
      service = business.services.create!(
        name: "Esmaltado",
        category: "Uñas",
        duration_minutes: 30,
        price_cents: 15_000,
        active: true,
        public_visible: true,
        visibility_mode: "public"
      )

      expect(described_class.publicly_bookable).to include(service)
    end
  end

  describe "#complete?" do
    it "does not require a positive price or description" do
      service = described_class.new(
        name: "Consulta inicial",
        category: "General",
        duration_minutes: 30,
        price_cents: 0
      )

      expect(service).to be_complete
    end
  end

  describe "#deposit_required?" do
    it "requires deposits to be enabled, the checkbox checked and a valid amount" do
      business = create_business(
        preferences: {
          "deposits_enabled" => true,
          "deposit_percentage" => 50
        }
      )
      invalid_service = business.services.build(
        name: "Consulta inicial",
        category: "General",
        description: "Evaluación inicial para definir el tratamiento.",
        duration_minutes: 30,
        price_cents: 20_000_00,
        deposit_required: true,
        deposit_amount_cents: 0
      )

      expect(invalid_service).not_to be_valid
      expect(invalid_service.errors[:deposit_amount]).to include("debe estar definido para pedir pago de seña")

      service = business.services.create!(
        name: "Consulta inicial",
        category: "General",
        description: "Evaluación inicial para definir el tratamiento.",
        duration_minutes: 30,
        price_cents: 20_000_00,
        deposit_required: true,
        deposit_amount_cents: 5_000_00
      )

      expect(service).to be_deposit_required
      expect(service.expected_deposit_amount_cents).to eq(5_000_00)
    end
  end

  describe "#deposit_amount_cents_for" do
    it "charges at most the service total while keeping zero-price services configurable" do
      business = create_business(preferences: { "deposits_enabled" => true })
      service = business.services.create!(
        name: "Limpieza facial",
        category: "Facial",
        duration_minutes: 60,
        price_cents: 10_000_00,
        deposit_required: true,
        deposit_amount_cents: 15_000_00
      )

      expect(service.deposit_amount_cents_for(10_000_00)).to eq(10_000_00)
      expect(service.deposit_amount_cents_for(0)).to eq(15_000_00)
    end
  end

  describe "#effective_public_start_interval_minutes" do
    it "uses the service duration when an old custom public interval is present" do
      service = described_class.new(duration_minutes: 30, public_start_interval_minutes: 15)

      expect(service.effective_public_start_interval_minutes).to eq(30)
    end

    it "defaults 15 minute services to 15 minute starts" do
      service = described_class.new(duration_minutes: 15)

      expect(service.effective_public_start_interval_minutes).to eq(15)
    end

    it "defaults 30 minute services to 30 minute starts" do
      service = described_class.new(duration_minutes: 30)

      expect(service.effective_public_start_interval_minutes).to eq(30)
    end

    it "uses 45 minute starts for 45 minute services" do
      service = described_class.new(duration_minutes: 45)

      expect(service.effective_public_start_interval_minutes).to eq(45)
    end

    it "uses 90 minute starts for 90 minute services" do
      service = described_class.new(duration_minutes: 90)

      expect(service.effective_public_start_interval_minutes).to eq(90)
    end

    it "allows only supported public intervals" do
      service = described_class.new(public_start_interval_minutes: 20)

      expect(service).not_to be_valid
      expect(service.errors[:public_start_interval_minutes]).to be_present
    end
  end

  describe "#available_on_date?" do
    it "requires a date within the configured range and an enabled weekday" do
      business = create_business
      service = business.services.create!(
        name: "Laminado de cejas",
        category: "Cejas",
        duration_minutes: 45,
        price_cents: 22_000_00,
        active: true,
        public_visible: true,
        visibility_mode: "public",
        limit_availability_by_date: true,
        availability_starts_on: Date.new(2026, 8, 7),
        availability_ends_on: Date.new(2026, 8, 31),
        use_advanced_availability: true
      )
      service.service_availability_rules.create!(weekday: 1, active: true, start_time: "09:00", end_time: "17:00")
      service.service_availability_rules.create!(weekday: 2, active: true, start_time: "09:00", end_time: "17:00")

      expect(service).not_to be_available_on_date(Date.new(2026, 8, 6))
      expect(service).to be_available_on_date(Date.new(2026, 8, 10))
      expect(service).to be_available_on_date(Date.new(2026, 8, 11))
      expect(service).not_to be_available_on_date(Date.new(2026, 8, 12))
      expect(service).not_to be_available_on_date(Date.new(2026, 9, 1))
    end
  end

  def create_business(preferences: {})
    owner = User.create!(
      email_address: "service-owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )

    Business.create!(
      owner: owner,
      name: "Service Test Center",
      slug: "service-test-center-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current,
      preferences: preferences
    )
  end
end
