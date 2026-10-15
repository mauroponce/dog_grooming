require "rails_helper"

RSpec.describe Billing::MonthlyAmountCalculator do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "charges a fixed $35.000 monthly amount for Basic" do
    business = create_business
    2.times { |index| create_employee(business, "Profesional #{index}") }

    result = described_class.call(business)

    expect(result.base_amount_cents).to eq(3_500_000)
    expect(result.active_professionals_count).to eq(2)
    expect(result.total_amount_cents).to eq(3_500_000)
  end

  it "does not add charges for more professionals" do
    business = create_business
    4.times { |index| create_employee(business, "Profesional #{index}") }

    result = described_class.call(business)

    expect(result.active_professionals_count).to eq(4)
    expect(result.total_amount_cents).to eq(3_500_000)
  end

  it "charges PRO at $45.000 with no usage or professional overages" do
    business = create_business
    business.subscription.update!(plan_selected: "pro")
    expect(described_class.call(business).total_amount_cents).to eq(4_500_000)
  end

  it "keeps the same amount for five active professionals" do
    business = create_business
    5.times { |index| create_employee(business, "Profesional #{index}") }

    result = described_class.call(business)

    expect(result.active_professionals_count).to eq(5)
    expect(result.total_amount_cents).to eq(3_500_000)
  end

  it "does not count pending, archived or non-bookable professionals" do
    business = create_business
    2.times { |index| create_employee(business, "Activa #{index}") }
    create_employee(business, "Invitada", status: "pending")
    create_employee(business, "Archivada", archived_at: Time.current, status: "revoked")
    create_employee(business, "Recepcionista", can_receive_appointments: false)

    result = described_class.call(business)

    expect(result.active_professionals_count).to eq(2)
    expect(result.total_amount_cents).to eq(3_500_000)
  end

  it "keeps new businesses trialing for fourteen days" do
    business = create_business

    expect(business.subscription.status).to eq("trialing")
    expect(business.trial_started_at).to be_present
    expect(business.trial_ends_at.to_date).to eq((business.trial_started_at + 14.days).to_date)
  end

  def create_business
    owner = User.create!(
      email_address: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      role: :admin
    )
    owner.create_business!(
      name: "Centro #{SecureRandom.hex(3)}",
      slug: "centro-#{SecureRandom.hex(4)}",
      business_kind: "business",
      industry: "aesthetics",
      contact_phone: "+5491111111111",
      onboarding_completed_at: Time.current
    )
  end

  def create_employee(business, name, status: "active", archived_at: nil, can_receive_appointments: true)
    first_name, last_name = employee_name_parts(name)
    membership = business.employee_memberships.create!(
      name: name,
      first_name: first_name,
      last_name: last_name,
      email_address: "#{name.parameterize}-#{SecureRandom.hex(3)}@example.com",
      status: status,
      archived_at: archived_at,
      can_receive_appointments: can_receive_appointments,
      permissions: EmployeeMembership::DEFAULT_PERMISSIONS.index_with { true }
    )
    if status == "active" && archived_at.blank?
      user = User.create!(
        email_address: membership.email_address,
        password: "password123",
        role: :employee
      )
      membership.update!(user: user, invitation_accepted_at: Time.current)
    end
    membership
  end

  def employee_name_parts(name)
    parts = name.to_s.split
    [ parts.first || "Profesional", parts.drop(1).join(" ").presence || "Test" ]
  end
end
