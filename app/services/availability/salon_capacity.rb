module Availability
  class SalonCapacity
    # Check the actual peak, rather than summing all appointments intersecting
    # the request: two successive bookings do not occupy two simultaneous cups.
    def self.available?(business:, starts_at:, ends_at:, excluding_appointment: nil, appointments: nil)
      return true if business.simultaneous_capacity.nil?

      intervals = if appointments
        appointments.filter_map do |appointment|
          next if appointment.id == excluding_appointment&.id || appointment.starts_at >= ends_at || appointment.ends_at <= starts_at

          [ appointment.starts_at, appointment.ends_at ]
        end
      else
        relation = Appointment.unscoped.active.where(business_id: business.id).where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
        relation = relation.where.not(id: excluding_appointment.id) if excluding_appointment&.persisted?
        relation.pluck(:starts_at, :ends_at)
      end
      events = intervals.flat_map do |from, to|
        [ [ [ from, starts_at ].max, 1 ], [ [ to, ends_at ].min, -1 ] ]
      end
      count = 0
      events.sort_by { |time, delta| [ time, delta ] }.all? do |_time, delta|
        count += delta
        count < business.simultaneous_capacity
      end
    end
  end
end
