class ServiceAvailabilityRule < ApplicationRecord
  belongs_to :service, touch: true

  validates :weekday, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true, if: :active?
  validate :end_time_after_start_time

  scope :active, -> { where(active: true) }
  scope :ordered, -> {
    order(Arel.sql("CASE weekday WHEN 1 THEN 0 WHEN 2 THEN 1 WHEN 3 THEN 2 WHEN 4 THEN 3 WHEN 5 THEN 4 WHEN 6 THEN 5 ELSE 6 END"))
  }

  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  def day_name
    Business::DAYS.to_h.fetch(weekday)
  end

  private
    def end_time_after_start_time
      return if start_time.blank? || end_time.blank?

      errors.add(:end_time, "debe ser posterior al inicio") if end_time <= start_time
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(service.business_id)
    end
end
