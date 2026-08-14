require "rails_helper"

RSpec.describe PhoneNormalizer do
  describe ".normalize" do
    it "keeps an Argentine mobile number with country code and mobile prefix" do
      expect(described_class.normalize("+54 9 11 1234-5678")).to eq("5491112345678")
    end

    it "adds country code and mobile prefix to a Buenos Aires local number" do
      expect(described_class.normalize("11 1234-5678")).to eq("5491112345678")
    end

    it "keeps an already normalized Argentine mobile number" do
      expect(described_class.normalize("5491112345678")).to eq("5491112345678")
    end

    it "adds the mobile prefix to an Argentine number with country code but without 9" do
      expect(described_class.normalize("+54 11 1234-5678")).to eq("5491112345678")
    end

    it "normalizes a Buenos Aires local mobile number that includes 15" do
      expect(described_class.normalize("15 1234-5678")).to eq("5491112345678")
    end
  end
end
