class Holiday < ApplicationRecord
  belongs_to :business, touch: true

  validates :date, :name, presence: true
  validates :date, uniqueness: { scope: :business_id }

  scope :closed, -> { where(closed: true) }
  scope :upcoming, -> { where("date >= ?", Time.zone.today).order(:date) }

  after_commit :broadcast_realtime_updates_later, on: %i[create update destroy]

  private
    def broadcast_realtime_updates_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end
end
