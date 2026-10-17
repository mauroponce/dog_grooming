module Customers
  class UpsertProfile
    def self.call(...)
      new(...).call
    end

    def initialize(business:, name:, phone:, email: nil)
      @business = business
      @name = name.to_s.squish.presence
      @phone = phone.to_s.squish.presence
      @email = email.to_s.squish.downcase.presence
    end

    def call
      normalized_phone = PhoneNumber.normalize(phone, area_code: business.mobile_area_code)
      profile = find_profile(normalized_phone) || business.customer_profiles.new

      assign_profile_attributes(profile)
      profile.save!
      profile
    end

    private
      attr_reader :business, :name, :phone, :email

      def find_profile(normalized_phone)
        return if normalized_phone.blank?

        profiles = business.customer_profiles.where(normalized_phone: PhoneNumber.lookup_values(phone, area_code: business.mobile_area_code)).order(:id).to_a
        profiles.find { |profile| profile.normalized_phone == normalized_phone } || profiles.first
      end

      def assign_profile_attributes(profile)
        profile.phone = phone if phone.present? && (profile.new_record? || profile.phone.blank?)
        profile.email = email if email.present? && profile.new_record?
        return if name.blank?
        return if profile.persisted? && profile.name.present?

        profile.name = name
      end
  end
end
