require "rails_helper"

RSpec.describe Business, type: :model do
  describe "slug validation" do
    it "does not allow reserved slugs" do
      business = build_business(slug: "admin")

      expect(business).not_to be_valid
      expect(business.errors[:slug]).to be_present
    end

    it "does not allow case-insensitive duplicates" do
      create_business(slug: "estetica-mauro")
      business = build_business(slug: "Estetica-Mauro")

      expect(business).not_to be_valid
      expect(business.errors[:slug]).to be_present
    end
  end

  describe "custom domains" do
    it "normalizes and resolves an enabled domain" do
      business = create_business(slug: "estetica-aura")
      business.update!(custom_domain: "HTTPS://Reserva.Aura.com.ar/", custom_domain_enabled: true)

      expect(business.custom_domain).to eq("reserva.aura.com.ar")
      expect(described_class.find_by_custom_domain("reserva.aura.com.ar")).to eq(business)
    end

    it "does not allow platform domains or an enabled blank domain" do
      business = build_business(slug: "estetica-aura")
      business.custom_domain = "cita.pet"

      expect(business).not_to be_valid
      expect(business.errors[:custom_domain]).to be_present

      business.custom_domain = nil
      business.custom_domain_enabled = true

      expect(business).not_to be_valid
      expect(business.errors[:custom_domain]).to be_present
    end
  end

  def build_business(slug:)
    owner = User.new(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    described_class.new(
      owner: owner,
      name: "Estética Mauro",
      slug: slug,
      contact_phone: "+54 9 11 2222-2222",
      onboarding_completed_at: Time.current
    )
  end

  def create_business(slug:)
    business = build_business(slug: slug)
    business.owner.save!
    business.save!
    business
  end
end
