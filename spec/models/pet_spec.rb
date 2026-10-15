require "rails_helper"

RSpec.describe Pet do
  let(:business) do
    owner = User.create!(email_address: "pet-#{SecureRandom.hex(4)}@example.com", password: "password123")
    owner.create_business!(name: "Pichipurris", slug: "pet-#{SecureRandom.hex(4)}", contact_phone: "+5491111111111")
  end
  let(:customer) { business.customer_profiles.create!(name: "Julieta", phone: "+5491122222222") }

  it "stores only supported grooming alerts and requires a detail for other coats" do
    pet = customer.pets.build(name: "Coco", coat_type: "other", behavioral_alerts: [ "blower_fear", "bite_risk" ])

    expect(pet).not_to be_valid
    expect(pet.errors[:coat_details]).to be_present

    pet.coat_details = "Manto mixto"
    expect(pet).to be_valid

    pet.behavioral_alerts = [ "unknown" ]
    expect(pet).not_to be_valid
    expect(pet.errors[:behavioral_alerts]).to be_present
  end

  it "clears an other-coat detail when a predefined coat is selected" do
    pet = customer.pets.create!(name: "Coco", coat_type: "long", coat_details: "No debe conservarse")

    expect(pet.coat_details).to be_nil
  end

  it "accepts only image reference photos" do
    pet = customer.pets.build(name: "Coco")
    pet.grooming_reference_photo.attach(io: StringIO.new("not an image"), filename: "reference.txt", content_type: "text/plain")

    expect(pet).not_to be_valid
    expect(pet.errors[:grooming_reference_photo]).to be_present
  end

  it "preserves staff alerts when a later booking updates the coat" do
    pet = customer.pets.create!(name: "Coco", behavioral_alerts: [ "blower_fear" ], grooming_reference_note: "Cara redonda")

    Pets::Upsert.call(business: business, customer_profile: customer, pet: pet, name: "Coco", coat_type: "long")

    expect(pet.reload).to have_attributes(coat_type: "long", behavioral_alerts: [ "blower_fear" ], grooming_reference_note: "Cara redonda")
  end
end
