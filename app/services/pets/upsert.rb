module Pets
  class Upsert
    ATTRIBUTES = %i[name breed sex birth_date notes coat_type coat_details behavioral_alerts grooming_reference_note pet_size_band].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(business:, customer_profile:, pet: nil, attributes: nil, preserve_existing: false, **pet_attributes)
      @business = business
      @customer_profile = customer_profile
      @pet = pet
      @preserve_existing = preserve_existing
      @attributes = extract_attributes(attributes).merge(extract_attributes(pet_attributes))
    end

    def call
      ensure_customer_profile_belongs_to_business!

      record = find_or_build_pet
      ensure_pet_belongs_to_scope!(record) if record.persisted?
      if record.persisted? && @preserve_existing
        # The selected size is explicitly reconfirmed on every booking.
        record.update!(pet_size_band: attributes[:pet_size_band]) if attributes[:pet_size_band].present?
        return record
      end
      # Selection flows often submit only a pet id. Do not erase profile data
      # already saved for that pet when optional fields are omitted.
      assignable_attributes = attributes.compact_blank
      assignable_attributes[:behavioral_alerts] = attributes[:behavioral_alerts] if attributes.key?(:behavioral_alerts)
      record.assign_attributes(assignable_attributes.merge(business: business, customer_profile: customer_profile))
      record.save!
      record
    end

    private
      attr_reader :business, :customer_profile, :pet, :attributes

      def extract_attributes(values)
        return {} if values.blank?

        values.to_h.symbolize_keys.slice(*ATTRIBUTES)
      end

      def find_or_build_pet
        return pet if pet.present?

        name = attributes[:name].to_s.squish.presence
        return customer_profile.pets.build if name.blank?

        matches = customer_profile.pets.where("LOWER(name) = ?", name.downcase).limit(2).to_a
        # Homonyms need staff selection. Do not choose one pet's history arbitrarily.
        matches.one? ? matches.first : customer_profile.pets.build
      end

      def ensure_customer_profile_belongs_to_business!
        return if customer_profile.business_id == business.id

        raise ArgumentError, "El cliente no pertenece a este negocio"
      end

      def ensure_pet_belongs_to_scope!(record)
        return if record.business_id == business.id && record.customer_profile_id == customer_profile.id

        raise ArgumentError, "La mascota no pertenece a este cliente o negocio"
      end
  end
end
