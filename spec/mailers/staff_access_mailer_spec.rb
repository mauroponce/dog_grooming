require "rails_helper"

RSpec.describe StaffAccessMailer, type: :mailer do
  it "builds a welcome email that points to the password login" do
    user = User.create!(
      email_address: "welcome-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    business = Business.create!(
      owner: user,
      name: "Aura Welcome",
      slug: "aura-welcome-#{SecureRandom.hex(4)}",
      contact_phone: "+54 9 11 5555-5555",
      onboarding_completed_at: Time.current
    )

    mail = described_class.welcome(user, business)

    expect(mail.to).to eq([ user.email_address ])
    expect(mail.subject).to eq("Tu cuenta de Cita.pet está lista")
    expect(mail.text_part.body.decoded).to include("http://localhost:3000/acceder")
    expect(mail.text_part.body.decoded).to include("email y la contraseña")
    expect(mail.text_part.body.decoded).not_to include("/acceso/")
    expect(mail.html_part.body.decoded).to include("/icon.png")
  end
end
