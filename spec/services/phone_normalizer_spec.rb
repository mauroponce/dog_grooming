require "rails_helper"

RSpec.describe PhoneNormalizer do
  describe ".normalize" do
    it "recognizes all supported representations of the same mobile" do
      [ "+541160347665", "+5491160347665", "1160347665", "1560347665", "011 15 6034-7665", "005491160347665" ].each do |phone|
        expect(described_class.normalize(phone, strict: true)).to eq("5491160347665")
      end
    end

    it "uses the business area only for local numbers" do
      [ "15 603-4765", "6034765", "0351 15 6034765", "3516034765", "+54 3516034765" ].each do |phone|
        expect(described_class.normalize(phone, area_code: "351", strict: true)).to eq("5493516034765")
      end
      expect(described_class.normalize("1160347665", area_code: "351", strict: true)).to eq("5491160347665")
      expect(described_class.normalize("02966 15 123456", strict: true)).to eq("5492966123456")
    end

    it "rejects incomplete or non-geographic mobiles in strict mode" do
      [ "123", "abc", "8001234567", "549116034766599" ].each do |phone|
        expect(described_class.normalize(phone, strict: true)).to be_nil
      end
    end

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
