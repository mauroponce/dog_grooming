module SuperAdmin
  class CreateDemoBusiness
    Result = Struct.new(:business, :email, keyword_init: true)

    def self.call
      new.call
    end

    def call
      suffix = Time.current.strftime("%Y%m%d%H%M%S")
      email = "demo-#{suffix}@cita.pet.test"
      business = nil
      User.transaction do
        owner = User.create!(email_address: email, name: business_attributes(suffix)[:name], role: :admin)
        business = owner.create_business!(business_attributes(suffix))
        professional = create_owner_professional!(business, owner)
        create_first_service!(business, professional)
      end

      Result.new(business: business, email: email)
    end

    private
      def business_attributes(suffix)
        {
          name: "Demo Cita.pet #{suffix.last(4)}",
          slug: Slugs::GenerateUnique.call("demo-cita-pet", scope: Business),
          business_kind: "business",
          industry: "dog_grooming",
          contact_phone: "+5491100000000",
          phone: "+5491100000000",
          city: "Buenos Aires",
          cancellation_notice_hours: 12,
          setup_status: "completed",
          onboarding_completed_at: Time.current,
          preferences: Business::PREFERENCE_DEFAULTS.merge(
            "deposits_enabled" => true,
            "deposit_percentage" => 50,
            "enabled_payment_methods" => [ "mercado_pago" ]
          )
        }
      end

      def create_owner_professional!(business, owner)
        business.employee_memberships.create!(
          user: owner,
          name: owner.name.presence || business.name,
          first_name: owner.name.to_s.split.first.presence || "Demo",
          last_name: owner.name.to_s.split.drop(1).join(" ").presence || "Grooming",
          email_address: owner.email_address,
          phone: business.contact_phone,
          specialty: business.industry_label,
          branch: business.branches.first,
          status: "active",
          invitation_sent_at: Time.current,
          invitation_accepted_at: Time.current,
          invited_by: owner,
          permissions: EmployeeMembership::PERMISSIONS.keys.index_with { true }
        )
      end

      def create_first_service!(business, professional)
        service = business.services.create!(
          name: "Baño y corte demo",
          category: "Baño y secado",
          description: "Servicio demo para validar el flujo de reserva pública de una mascota.",
          duration_minutes: 60,
          price_cents: 30_000_00,
          deposit_required: true,
          deposit_amount_cents: 10_000_00,
          visibility_mode: "public",
          professional_selection_mode: "hidden",
          active: true,
          public_visible: true,
          popular: true
        )
        service.employee_memberships << professional
        service
      end
  end
end
