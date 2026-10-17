class ServiceTag < ApplicationRecord
  TAG_TYPES = %w[keyword synonym].freeze

  belongs_to :service, touch: true

  before_validation :normalize_name
  after_commit :broadcast_public_services_later, on: %i[create update destroy]

  validates :name, :tag_type, presence: true
  validates :tag_type, inclusion: { in: TAG_TYPES }
  validates :name, uniqueness: { scope: [ :service_id, :tag_type ] }

  private
    def normalize_name
      self.name = name.to_s.strip.downcase
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(service.business_id)
    end
end
