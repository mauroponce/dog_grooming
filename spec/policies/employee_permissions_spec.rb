require "rails_helper"

RSpec.describe "employee permissions" do
  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "does not allow billing or team access by default" do
    business = create_business
    membership = create_employee(business, "Sofia")
    user = create_employee_user(membership)
    policy = BusinessPolicy.new(user, business)

    expect(policy.billing?).to eq(false)
    expect(policy.employees?).to eq(false)
    expect(policy.services?).to eq(false)
    expect(policy.resources?).to eq(false)
  end

  it "scopes appointments to the employee agenda by default" do
    business = create_business
    service = create_service(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    user = create_employee_user(sofia)
    own_appointment = create_appointment(business, service, sofia, Time.zone.local(2026, 7, 1, 10, 0))
    other_appointment = create_appointment(business, service, camila, Time.zone.local(2026, 7, 1, 12, 0))

    scoped = AppointmentPolicy::Scope.new(user, business.appointments).resolve

    expect(scoped).to include(own_appointment)
    expect(scoped).not_to include(other_appointment)
  end

  it "lets admins see all appointments" do
    business = create_business
    service = create_service(business)
    sofia = create_employee(business, "Sofia")
    camila = create_employee(business, "Camila")
    create_appointment(business, service, sofia, Time.zone.local(2026, 7, 1, 10, 0))
    create_appointment(business, service, camila, Time.zone.local(2026, 7, 1, 12, 0))

    scoped = AppointmentPolicy::Scope.new(business.owner, business.appointments).resolve

    expect(scoped.count).to eq(2)
  end

  it "does not let employees approve deposits by default" do
    business = create_business
    service = create_service(business)
    membership = create_employee(business, "Sofia")
    user = create_employee_user(membership)
    appointment = create_appointment(business, service, membership, Time.zone.local(2026, 7, 1, 10, 0), status: :pending_deposit_review, deposit_status: "submitted")

    expect(AppointmentPolicy.new(user, appointment).approve_deposit?).to eq(false)
  end

  it "allows employees with deposit permission to approve their own appointments" do
    business = create_business
    service = create_service(business)
    membership = create_employee(business, "Sofia", permissions: EmployeeMembership::DEFAULT_PERMISSIONS + %w[can_approve_deposits])
    user = create_employee_user(membership)
    appointment = create_appointment(business, service, membership, Time.zone.local(2026, 7, 1, 10, 0), status: :pending_deposit_review, deposit_status: "submitted")

    expect(AppointmentPolicy.new(user, appointment).approve_deposit?).to eq(true)
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

  def create_service(business)
    business.services.create!(
      name: "Limpieza facial",
      category: "Facial",
      description: "Servicio de prueba",
      duration_minutes: 60,
      price_cents: 20_000_00
    )
  end

  def create_employee(business, name, permissions: EmployeeMembership::DEFAULT_PERMISSIONS)
    first_name, last_name = employee_name_parts(name)
    business.employee_memberships.create!(
      name: name,
      first_name: first_name,
      last_name: last_name,
      email_address: "#{name.parameterize}-#{SecureRandom.hex(3)}@example.com",
      status: "active",
      permissions: permissions.index_with { true }
    )
  end

  def employee_name_parts(name)
    parts = name.to_s.split
    [ parts.first || "Profesional", parts.drop(1).join(" ").presence || "Test" ]
  end

  def create_employee_user(membership)
    user = User.create!(
      email_address: membership.email_address,
      password: "password123",
      role: :employee
    )
    membership.update!(user: user, invitation_accepted_at: Time.current)
    user
  end

  def create_appointment(business, service, employee, starts_at, status: :confirmed, deposit_status: "not_required")
    business.appointments.create!(
      service: service,
      employee_membership: employee,
      customer_name: "Cliente #{SecureRandom.hex(2)}",
      customer_phone: "+54911#{rand(10_000_000..99_999_999)}",
      starts_at: starts_at,
      status: status,
      deposit_status: deposit_status,
      source: :manual,
      base_price_cents: service.price_cents,
      final_price_cents: service.price_cents
    )
  end
end
