module Pets
  class Upsert
    ATTRIBUTES = %i[name breed sex birth_date notes].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(business:, customer_profile:, pet: nil, attributes: nil, **pet_attributes)
      @business = business
      @customer_profile = customer_profile
      @pet = pet
      @attributes = extract_attributes(attributes).merge(extract_attributes(pet_attributes))
    end

    def call
      ensure_customer_profile_belongs_to_business!

      record = find_or_build_pet
      ensure_pet_belongs_to_scope!(record) if record.persisted?
      # Selection flows often submit only a pet id. Do not erase profile data
      # already saved for that pet when optional fields are omitted.
      record.assign_attributes(attributes.compact_blank.merge(business: business, customer_profile: customer_profile))
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

        customer_profile.pets.where("LOWER(name) = ?", name.downcase).first || customer_profile.pets.build
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
