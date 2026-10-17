require "rails_helper"

RSpec.describe Customers::NormalizeMobileNumbers do
  it "audits first and only changes unambiguous keys, considering deleted customers" do
    owner = User.create!(email_address: "normalization-#{SecureRandom.hex(4)}@example.com", password: "password123")
    business = Business.create!(owner: owner, name: "Peluquería", slug: "normalize-#{SecureRandom.hex(4)}", contact_phone: "1160347665")
    first = business.customer_profiles.create!(name: "Uno", phone: "1160347665")
    first.update_columns(normalized_phone: "+541160347665")
    deleted = business.customer_profiles.create!(name: "Eliminado", phone: "1177777777", deleted_at: Time.current)
    duplicate = business.customer_profiles.create!(name: "Otro", phone: "1188888888")
    duplicate.update_columns(phone: "1177777777", normalized_phone: "+541177777777")

    expect(described_class.call(business: business)).to eq(updated: 1, collisions: 2, invalid: 0)
    expect(first.reload.normalized_phone).to eq("+541160347665")
    described_class.call(business: business, apply: true)
    expect(first.reload.normalized_phone).to eq("5491160347665")
    expect(duplicate.reload.normalized_phone).to eq("+541177777777")
    expect(CustomerProfile.unscoped.find(deleted.id).normalized_phone).to eq("5491177777777")
  end
end
