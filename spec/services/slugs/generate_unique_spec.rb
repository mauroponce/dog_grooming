require "rails_helper"

RSpec.describe Slugs::GenerateUnique do
  describe ".normalize" do
    it "removes accents and normalizes separators" do
      expect(described_class.normalize("Estética Mauro")).to eq("estetica-mauro")
      expect(described_class.normalize("  Estética   Mauro Palermo  ")).to eq("estetica-mauro-palermo")
    end
  end

  describe ".call" do
    it "returns the base slug when it is available" do
      expect(described_class.call("Estética Mauro", scope: Business)).to eq("estetica-mauro")
    end

    it "increments the suffix when the slug already exists" do
      create_business(slug: "estetica-mauro")
      create_business(slug: "estetica-mauro-2")

      expect(described_class.call("Estética Mauro", scope: Business)).to eq("estetica-mauro-3")
    end

    it "skips reserved words" do
      expect(described_class.call("admin", scope: Business)).to eq("admin-2")
    end
  end

  describe ".valid?" do
    it "rejects reserved words and invalid formats" do
      expect(described_class.valid?("admin")).to eq(false)
      expect(described_class.valid?("estetica--mauro")).to eq(false)
      expect(described_class.valid?("-estetica")).to eq(false)
      expect(described_class.valid?("es")).to eq(false)
    end
  end

  def create_business(slug:)
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    Business.create!(
      owner: owner,
      name: "Estética Mauro",
      slug: slug,
      contact_phone: "+54 9 11 2222-2222",
      onboarding_completed_at: Time.current
    )
  end
end
