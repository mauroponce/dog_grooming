module Registrations
  class CreateBusinessAccount
    Result = Struct.new(:business, :owner, keyword_init: true)
    def self.call(...) = new(...).call
    def initialize(params, identity:) = (@params = params.to_h.symbolize_keys; @identity = identity)

    def call
      validate!
      User.transaction do
        owner = User.create!(
          email_address: identity.email_address,
          name: owner_name,
          google_uid: identity.uid,
          google_connected_at: Time.current,
          last_login_provider: "google",
          role: :admin
        )
        business = owner.create_business!(name: business_name, slug: slug, business_kind: "business", industry: "dog_grooming", contact_phone: contact_phone, phone: contact_phone, setup_status: "not_started")
        business.update!(simultaneous_capacity: 3, arrival_mode: "fixed", arrival_times: (0..6).to_h { |day| [ day.to_s, %w[09:00 12:00 15:00] ] }, preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "mercado_pago" ]))
        business.subscription.update!(plan_selected: plan_selected, amount_cents: Subscription::PLANS.fetch(plan_selected).fetch(:amount_cents))
        Grooming::Catalog.install!(business)
        business.employee_memberships.create!(user: owner, name: owner_name, first_name: owner_name.split.first, last_name: owner_name.split.drop(1).join(" ").presence || "Principal", email_address: owner.email_address, phone: contact_phone, specialty: business.industry_label, branch: business.branches.first, status: "active", invitation_accepted_at: Time.current, invited_by: owner, permissions: EmployeeMembership::PERMISSIONS.keys.index_with { true })
        business.employee_memberships.find_by!(user: owner).update!(can_receive_appointments: false)
        Result.new(business: business, owner: owner)
      end
    end

    private
      attr_reader :params
      def business_name = params[:business_name].to_s.squish
      def owner_name = params[:owner_name].to_s.squish
      def contact_phone = params[:contact_phone].to_s.strip
      def slug = Business.slug_for(params[:slug].presence || business_name)
      def plan_selected = params[:plan_selected].presence || "basic"
      def validate!
        raise ArgumentError, "Elegí Básico o PRO." unless Subscription::PLANS.key?(plan_selected)
        raise ArgumentError, "Completá el nombre de la peluquería." if business_name.blank?
        raise ArgumentError, "Completá tu nombre." if owner_name.blank?
        raise ArgumentError, "Completá tu teléfono." if contact_phone.blank?
        raise ArgumentError, "Ese email ya tiene una cuenta." if User.exists?(email_address: identity.email_address) || User.exists?(google_uid: identity.uid)
        raise ArgumentError, "El link elegido no está disponible." unless Slugs::GenerateUnique.valid?(slug) && Slugs::GenerateUnique.available?(slug, scope: Business)
      end

      attr_reader :identity
  end
end
