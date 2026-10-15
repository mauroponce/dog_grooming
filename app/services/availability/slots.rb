module Availability
  class Slots
    def self.for(business:, service:, date:, employee_membership: nil)
      AvailableSlots.times(business:, service:, date:, employee_membership:)
    end

    def self.records_for(business:, service:, date:, employee_membership: nil)
      AvailableSlots.for(business:, service:, date:, employee_membership:)
    end

    def self.public_for(business:, service:, date:, employee_membership: nil)
      public_records_for(business:, service:, date:, employee_membership:).map(&:starts_at).uniq.sort
    end

    def self.public_records_for(business:, service:, date:, employee_membership: nil, excluding_appointment: nil)
      AvailableSlots.for(business:, service:, date:, employee_membership:, excluding_appointment:, online_booking: true)
    end

    def self.first_record_for(business:, service:, date:, employee_membership: nil)
      AvailableSlots.new(business:, service:, date:, employee_membership:).first_slot
    end

    def self.available?(business:, service:, starts_at:, employee_membership: nil)
      AvailableSlots.available?(business:, service:, starts_at:, employee_membership:)
    end

    def self.public_available?(business:, service:, starts_at:, employee_membership: nil, excluding_appointment: nil)
      AvailableSlots.available?(business:, service:, starts_at:, employee_membership:, excluding_appointment:, online_booking: true)
    end
  end
end
