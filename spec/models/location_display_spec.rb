require "rails_helper"

RSpec.describe "Location display" do
  it "does not duplicate the business city when the street address already includes it" do
    business = Business.new(
      address: "Jorge Santiago Bynnon 1839, Adrogué",
      address_details: "2B",
      city: "Adrogué",
      province: "Buenos Aires"
    )

    expect(business.public_location).to eq("Jorge Santiago Bynnon 1839, 2B, Adrogué, Buenos Aires")
    expect(business.location_search_address).to eq("Jorge Santiago Bynnon 1839, Adrogué, Buenos Aires")
  end

  it "does not duplicate branch locality fields" do
    branch = Branch.new(
      address: "Jorge Santiago Bynnon 1839, Adrogué",
      address_details: "2B",
      neighborhood: "Adrogué",
      city: "Adrogué",
      province: "Buenos Aires"
    )

    expect(branch.public_location).to eq("Jorge Santiago Bynnon 1839, 2B, Adrogué, Buenos Aires")
    expect(branch.location_search_address).to eq("Jorge Santiago Bynnon 1839, Adrogué, Buenos Aires")
  end
end
