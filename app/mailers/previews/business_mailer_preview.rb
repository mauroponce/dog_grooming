class BusinessMailerPreview < ActionMailer::Preview
  def new_deposit_proof
    BusinessMailer.new_deposit_proof(sample_appointment)
  end

  def new_waitlist_entry
    BusinessMailer.new_waitlist_entry(sample_waitlist_entry)
  end

  def follow_up_digest
    BusinessMailer.follow_up_digest(sample_business, sample_business.customer_reminders.limit(3))
  end

  def daily_digest
    BusinessMailer.daily_digest(sample_business)
  end

  def weekly_digest
    BusinessMailer.weekly_digest(sample_business)
  end

  private
    def sample_business
      Business.first || raise("Creá un negocio o corré seeds para ver previews de BusinessMailer.")
    end

    def sample_service
      sample_business.services.first || Service.new(
        business: sample_business,
        name: "Baño y corte",
        category: "Baño y secado",
        duration_minutes: 60,
        price_cents: 35_000_00
      )
    end

    def sample_customer
      sample_business.customer_profiles.first || CustomerProfile.new(
        business: sample_business,
        name: "Julieta Ramos",
        phone: "+5491112345678",
        normalized_phone: PhoneNumber.normalize("+5491112345678")
      )
    end

    def sample_appointment
      sample_business.appointments.awaiting_deposit_review.first || sample_business.appointments.first || Appointment.new(
        business: sample_business,
        service: sample_service,
        customer_profile: sample_customer,
        customer_name: sample_customer.name,
        customer_phone: sample_customer.phone,
        starts_at: 1.day.from_now.change(hour: 15, min: 30),
        ends_at: 1.day.from_now.change(hour: 16, min: 30),
        status: :pending_deposit_review,
        deposit_status: "submitted",
        deposit_amount_cents: 8_000_00,
        base_price_cents: 35_000_00,
        final_price_cents: 35_000_00
      )
    end

    def sample_waitlist_entry
      sample_business.waitlist_entries.first || WaitlistEntry.new(
        center: sample_business,
        service: sample_service,
        customer_profile: sample_customer,
        client_name: sample_customer.name,
        client_phone: sample_customer.phone,
        desired_date: Time.zone.today,
        preferred_time_windows: [ "Tarde" ],
        notes: "Prefiere después de las 16 hs.",
        source: "public_page",
        status: "waiting"
      )
    end
end
