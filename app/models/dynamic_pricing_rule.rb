class DynamicPricingRule < ApplicationRecord
  belongs_to :center, class_name: "Business", foreign_key: :center_id, inverse_of: :dynamic_pricing_rules

  validates :day_of_week, inclusion: { in: 0..6 }
  validates :start_time, :end_time, :discount_percentage, presence: true
  validates :discount_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validate :end_time_after_start_time

  scope :active, -> { where(active: true) }

  def weekday_name
    Business::DAYS.to_h.fetch(day_of_week)
  end

  private
    def end_time_after_start_time
      return if start_time.blank? || end_time.blank?

      errors.add(:end_time, "debe ser posterior al inicio") if end_time <= start_time
    end
end
