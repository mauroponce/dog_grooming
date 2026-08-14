class EmployeeAvailabilityRule < ApplicationRecord
  belongs_to :employee_membership, touch: true

  validates :weekday, inclusion: { in: 0..6 }
  validates :weekday, uniqueness: { scope: :employee_membership_id }
  validates :start_time, :end_time, presence: true, if: :active?
  validate :end_time_after_start_time
  validate :break_time_range
  after_commit :broadcast_realtime_updates_later, on: %i[create update destroy]

  scope :ordered, -> {
    order(Arel.sql("CASE weekday WHEN 1 THEN 0 WHEN 2 THEN 1 WHEN 3 THEN 2 WHEN 4 THEN 3 WHEN 5 THEN 4 WHEN 6 THEN 5 ELSE 6 END"))
  }

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

    def broadcast_realtime_updates_later
      PublicBooking::BroadcastServicesJob.perform_later(employee_membership.business_id)
    end
end
