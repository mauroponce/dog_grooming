class AvailabilityRule < ApplicationRecord
  belongs_to :business, touch: true

  validates :weekday, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true, if: :active?
  validate :end_time_after_start_time
  validate :break_time_range
  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  def day_name
    Business::DAYS.to_h.fetch(weekday)
  end

  private
    def end_time_after_start_time
      return if start_time.blank? || end_time.blank?

      errors.add(:end_time, "debe ser posterior al inicio") if end_time <= start_time
    end

    def break_time_range
      return if break_start_time.blank? && break_end_time.blank?

      errors.add(:break_end_time, "debe completarse") if break_start_time.present? && break_end_time.blank?
      errors.add(:break_start_time, "debe completarse") if break_start_time.present? == false && break_end_time.present?
      return if break_start_time.blank? || break_end_time.blank?

      errors.add(:break_end_time, "debe ser posterior al inicio del descanso") if break_end_time <= break_start_time
      return if start_time.blank? || end_time.blank?

      errors.add(:break_start_time, "debe estar dentro del horario") if break_start_time < start_time || break_start_time >= end_time
      errors.add(:break_end_time, "debe estar dentro del horario") if break_end_time <= start_time || break_end_time > end_time
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end
end
