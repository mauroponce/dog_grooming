unless Rails.env.development?
  abort "db:seed solo está habilitado en development. En producción usá citapet:bootstrap_super_admin."
end

class DevelopmentSeeds
  DEMO_SLUGS = %w[demo-patitas demo-trial demo-restringida].freeze
  DEMO_EMAILS = %w[
    superadmin@demo.cita.pet.test
    admin@demo-patitas.cita.pet.test
    equipo@demo-patitas.cita.pet.test
    admin@demo-trial.cita.pet.test
    admin@demo-restringida.cita.pet.test
  ].freeze

  def self.call = new.call

  def call
    ActiveRecord::Base.transaction do
      remove_previous_demo!
      seed_super_admin!
      seed_active_business!
      seed_lifecycle_business!(slug: "demo-trial", status: "trialing")
      seed_lifecycle_business!(slug: "demo-restringida", status: "restricted")
    end

    puts <<~MESSAGE

      Datos demo listos (solo development):
        Panel:       http://localhost:3003/admin
        Reserva:     http://localhost:3003/demo-patitas
        Superadmin:  superadmin@demo.cita.pet.test
        Propietaria: admin@demo-patitas.cita.pet.test

      El acceso usa Google. Los emails quedan preaprovisionados y no se crean contraseñas demo.
    MESSAGE
  end

  private
    def remove_previous_demo!
      Business.where(slug: DEMO_SLUGS).find_each do |business|
        # CustomerReminder references Appointment without ON DELETE CASCADE and
        # Business declares appointments before reminders in its associations.
        business.customer_reminders.destroy_all
        business.destroy!
      end
      User.where(email_address: DEMO_EMAILS).find_each do |user|
        user.destroy! unless user.business.present? || user.employee_memberships.exists?
      end
    end

    def seed_super_admin!
      User.create!(email_address: "superadmin@demo.cita.pet.test", name: "Superadmin Demo", role: :super_admin)
    end

    def seed_active_business!
      owner, business, owner_membership = create_business(
        slug: "demo-patitas",
        name: "Patitas Demo",
        owner_email: "admin@demo-patitas.cita.pet.test",
        subscription_status: "active",
        trial_ends_at: 30.days.from_now
      )

      business.update!(
        onboarding_completed_at: Time.current,
        setup_status: "completed",
        public_landing_enabled: true,
        public_headline: "Cuidado profesional para tu perro",
        contact_phone: "+5491112345678",
        address: "Av. Cabildo 1840",
        city: "Buenos Aires",
        neighborhood: "Belgrano",
        simultaneous_capacity: 3,
        preferences: business.preferences.merge(
          "deposits_enabled" => true,
          "deposit_percentage" => 50,
          "enabled_payment_methods" => [ "manual_transfer" ],
          "deposit_instructions" => "Transferí la seña y adjuntá el comprobante."
        )
      )
      configure_hours!(business)

      account = business.payment_accounts.create!(
        name: "Cuenta demo",
        details: "Banco Demo\nAlias: patitas.demo\nTitular: Patitas Demo",
        primary_account: true
      )

      employee_user = User.create!(email_address: "equipo@demo-patitas.cita.pet.test", name: "Lucía Groomer", role: :employee)
      employee = business.employee_memberships.create!(
        user: employee_user,
        invited_by: owner,
        name: "Lucía Groomer",
        first_name: "Lucía",
        last_name: "Groomer",
        email_address: employee_user.email_address,
        status: "active",
        invitation_accepted_at: 1.month.ago,
        specialty: "Baño y corte",
        sort_order: 1,
        permissions: EmployeeMembership::ACCESS_LEVELS.fetch("medium").fetch(:permissions).index_with { true }
      )
      business.employee_memberships.create!(
        invited_by: owner,
        name: "Martina Pendiente",
        first_name: "Martina",
        last_name: "Pendiente",
        email_address: "martina.pendiente@demo.cita.pet.test",
        status: "pending",
        invitation_sent_at: 1.day.ago,
        invitation_expires_at: 6.days.from_now,
        invitation_token_digest: BCrypt::Password.create(SecureRandom.hex(24)),
        can_receive_appointments: false,
        sort_order: 2
      )

      Grooming::Catalog.install!(business)
      deposit_services = business.services.order(:sort_order, :id).to_a
      deposit_services.each_with_index do |service, index|
        service.update!(
          payment_account: account,
          active: true,
          public_visible: true,
          visibility_mode: "public",
          professional_selection_mode: "hidden",
          sort_order: index,
          follow_up_enabled: true,
          recommended_follow_up_days: 30
        )
      end

      category = ServiceCategory.find_or_create_for!(business: business, name: "Higiene")
      nail_service = business.services.create!(
        service_category: category,
        name: "Corte de uñas",
        category: category.name,
        description: "Corte y limado de uñas.",
        duration_minutes: 30,
        price_cents: 8_000_00,
        deposit_required: false,
        active: true,
        public_visible: true,
        visibility_mode: "public",
        professional_selection_mode: "hidden",
        sort_order: 10
      )

      returning = create_customer!(business, name: "Sofía Morales", phone: "+5491111111101", email: "sofia@example.test")
      returning_pet = returning.pets.create!(
        business: business,
        name: "Milo",
        breed: "Caniche",
        sex: "male",
        birth_date: 4.years.ago.to_date,
        coat_type: "curly",
        behavioral_alerts: [ "blower_fear" ],
        pet_size_band: business.pet_size_bands.order(:position).second
      )
      blocked = create_customer!(business, name: "Cliente Bloqueado", phone: "+5491111111102", email: "bloqueado@example.test")
      blocked.block!("Dos ausencias sin aviso")
      blocked.pets.create!(business: business, name: "Toby", breed: "Mestizo", sex: "male")
      newcomer = create_customer!(business, name: "Carla Nueva", phone: "+5491111111103", email: "carla@example.test")
      newcomer_pet = newcomer.pets.create!(
        business: business,
        name: "Lola",
        breed: "Golden retriever",
        sex: "female",
        coat_type: "double",
        pet_size_band: business.pet_size_bands.order(:position).last
      )

      variant = deposit_services.first.service_variants.active.order(:id).second
      appointments = [
        create_appointment!(business:, service: nail_service, customer: returning, pet: returning_pet, employee: owner_membership, starts_at: 14.days.ago.change(hour: 10), status: :completed),
        create_appointment!(business:, service: nail_service, customer: returning, pet: returning_pet, employee: owner_membership, starts_at: 7.days.ago.change(hour: 11), status: :no_show),
        create_appointment!(business:, service: nail_service, customer: newcomer, pet: newcomer_pet, employee:, starts_at: 2.days.from_now.change(hour: 9), status: :confirmed),
        create_appointment!(business:, service: deposit_services.first, variant:, customer: returning, pet: returning_pet, employee:, starts_at: 3.days.from_now.change(hour: 11), status: :pending_deposit, deposit_status: "pending"),
        create_appointment!(business:, service: deposit_services.first, variant:, customer: newcomer, pet: newcomer_pet, employee: owner_membership, starts_at: 4.days.from_now.change(hour: 13), status: :pending_deposit_review, deposit_status: "submitted"),
        create_appointment!(business:, service: deposit_services.first, variant:, customer: returning, pet: returning_pet, employee:, starts_at: 5.days.from_now.change(hour: 15), status: :deposit_rejected, deposit_status: "rejected"),
        create_appointment!(business:, service: deposit_services.first, variant:, customer: newcomer, pet: newcomer_pet, employee: owner_membership, starts_at: 6.days.from_now.change(hour: 10), status: :confirmed, deposit_status: "approved"),
        create_appointment!(business:, service: nail_service, customer: returning, pet: returning_pet, employee:, starts_at: 8.days.from_now.change(hour: 12), status: :canceled)
      ]

      business.customer_reminders.create!(
        customer_profile: returning,
        service: deposit_services.first,
        appointment: appointments.first,
        assigned_to: owner,
        reminder_type: "service_follow_up",
        body: "Contactar para coordinar el próximo baño.",
        remind_at: 1.day.ago,
        status: "pending"
      )
      business.customer_reminders.create!(
        customer_profile: newcomer,
        assigned_to: owner,
        reminder_type: "manual",
        body: "Confirmar indicaciones para el manto de Lola.",
        remind_at: 2.days.from_now,
        status: "resolved",
        completed_at: Time.current,
        completed_by: owner
      )

      business.provider_events.create!(event_type: "new_booking", title: "Nueva reserva online", body: "Carla reservó un turno para Lola.", metadata: { appointment_id: appointments.third.id })
      business.provider_events.create!(event_type: "deposit_proof_submitted", title: "Comprobante para revisar", body: "Hay una seña pendiente de revisión.", metadata: { appointment_id: appointments.fifth.id })
      create_invoice!(business, status: "paid", due_on: 10.days.ago.to_date, paid_at: 12.days.ago)
    end

    def seed_lifecycle_business!(slug:, status:)
      email = "admin@#{slug}.cita.pet.test"
      _owner, business, = create_business(
        slug: slug,
        name: status == "trialing" ? "Peluquería en Prueba" : "Peluquería Restringida",
        owner_email: email,
        subscription_status: status,
        trial_ends_at: status == "trialing" ? 7.days.from_now : 20.days.ago
      )
      business.update!(
        onboarding_completed_at: status == "trialing" ? nil : 2.months.ago,
        setup_status: status == "trialing" ? "in_progress" : "completed"
      )
      Grooming::Catalog.install!(business)
      return unless status == "restricted"

      business.subscription.update!(restricted_at: 2.days.ago, next_due_on: 20.days.ago.to_date, grace_ends_on: 5.days.ago.to_date)
      create_invoice!(business, status: "overdue", due_on: 20.days.ago.to_date, overdue_at: 17.days.ago)
    end

    def create_business(slug:, name:, owner_email:, subscription_status:, trial_ends_at:)
      owner = User.create!(email_address: owner_email, name: "Dueña de #{name}", role: :admin)
      business = Business.create!(
        owner: owner,
        slug: slug,
        name: name,
        industry: "dog_grooming",
        mobile_area_code: "11",
        trial_started_at: 7.days.ago,
        trial_ends_at: trial_ends_at,
        setup_status: "completed"
      )
      membership = business.employee_memberships.create!(
        user: owner,
        invited_by: owner,
        name: owner.name,
        first_name: "Dueña",
        last_name: name,
        email_address: owner.email_address,
        status: "active",
        invitation_accepted_at: Time.current,
        specialty: "Administración",
        permissions: EmployeeMembership::PERMISSIONS.keys.index_with { true },
        can_receive_appointments: true,
        sort_order: 0
      )
      business.subscription.update!(
        status: subscription_status,
        external_reference: "seed-#{slug}",
        payer_email: owner.email_address,
        paid_until: subscription_status == "active" ? 1.month.from_now.to_date : nil,
        next_due_on: trial_ends_at.to_date
      )
      [ owner, business, membership ]
    end

    def configure_hours!(business)
      business.availability_rules.each do |rule|
        weekday = rule.weekday.in?(1..6)
        rule.update!(active: weekday, start_time: "09:00", end_time: weekday ? "19:00" : "18:00")
      end
    end

    def create_customer!(business, name:, phone:, email:)
      first_name, last_name = name.split(" ", 2)
      business.customer_profiles.create!(name:, first_name:, last_name:, phone:, email:)
    end

    def create_appointment!(business:, service:, customer:, pet:, employee:, starts_at:, status:, variant: nil, deposit_status: "not_required")
      duration = variant&.duration_minutes || service.duration_minutes
      price = variant&.price_cents || service.price_cents
      deposit_amount = deposit_status == "not_required" ? 0 : service.deposit_amount_cents_for(price)
      business.appointments.create!(
        service: service,
        service_variant: variant,
        customer_profile: customer,
        pet: pet,
        employee_membership: employee,
        customer_name: customer.name,
        customer_phone: customer.phone,
        customer_email: customer.email,
        starts_at: starts_at,
        ends_at: starts_at + duration.minutes,
        status: status,
        source: :public_booking,
        base_price_cents: price,
        final_price_cents: price,
        service_variant_name: variant&.display_name,
        service_variant_price_cents: variant&.price_cents,
        service_variant_duration_minutes: variant&.duration_minutes,
        deposit_status: deposit_status,
        deposit_amount_cents: deposit_amount,
        deposit_submitted_at: deposit_status == "submitted" ? 1.hour.ago : nil,
        deposit_reviewed_at: deposit_status.in?(%w[approved rejected]) ? 1.hour.ago : nil,
        deposit_rejection_reason: deposit_status == "rejected" ? "El importe no se distingue en el comprobante." : nil,
        payment_collection_method: deposit_status == "not_required" ? "none" : "manual_proof",
        payment_charge_mode: deposit_status == "not_required" ? "none" : "deposit",
        payment_expires_at: deposit_status.in?(%w[pending rejected]) ? 30.minutes.from_now : nil,
        confirmed_at: status == :confirmed ? Time.current : nil,
        completed_at: status == :completed ? starts_at + duration.minutes : nil,
        no_show_at: status == :no_show ? starts_at + duration.minutes : nil,
        canceled_at: status == :canceled ? Time.current : nil,
        canceled_by: status == :canceled ? "customer_link" : nil,
        cancellation_reason: status == :canceled ? "No podrá asistir." : nil
      )
    end

    def create_invoice!(business, status:, due_on:, paid_at: nil, overdue_at: nil)
      period_start = due_on.beginning_of_month
      business.subscription_invoices.create!(
        subscription: business.subscription,
        amount_cents: business.subscription.amount_cents,
        billing_period_months: 1,
        period_start: period_start,
        period_end: period_start.next_month,
        due_on: due_on,
        reference_code: "SEED-#{business.slug.upcase}-#{due_on.strftime('%Y%m')}",
        plan_selected: business.subscription.plan_selected,
        status: status,
        paid_at: paid_at,
        overdue_at: overdue_at
      )
    end
end

DevelopmentSeeds.call
