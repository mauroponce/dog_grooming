module Customers
  # Explicit, resumable maintenance. Includes deleted profiles because their
  # normalized numbers still participate in the database's unique index.
  class NormalizeMobileNumbers
    def self.call(business:, apply: false)
      counts = { updated: 0, collisions: 0, invalid: 0 }
      business.with_lock do
        profiles = CustomerProfile.unscoped.where(business: business).to_a
        grouped = profiles.group_by { |profile| PhoneNumber.normalize(profile.phone, area_code: business.mobile_area_code, strict: true) }
        grouped.each do |canonical, members|
          if canonical.blank?
            counts[:invalid] += members.size
          elsif members.many? || profiles.any? { |profile| profile.normalized_phone == canonical && !members.include?(profile) }
            counts[:collisions] += members.size
          else
            profile = members.first
            next if profile.normalized_phone == canonical

            profile.update_columns(normalized_phone: canonical) if apply
            counts[:updated] += 1
          end
        end
      end
      counts
    end
  end
end
