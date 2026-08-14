class CommercialCalendarEvent < ApplicationRecord
  CATEGORIES = %w[seasonal beauty retail holiday].freeze

  validates :name, :event_date, :country, :category, presence: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :active, -> { where(active: true) }
  scope :upcoming, ->(from = Time.zone.today) { active.where("event_date >= ?", from).order(:event_date) }

  def self.seed_argentina_defaults!
    [
      [ "San Valentín", Date.new(Time.zone.today.year, 2, 14), "seasonal" ],
      [ "Día de la Mujer", Date.new(Time.zone.today.year, 3, 8), "seasonal" ],
      [ "Día de la Madre", Date.new(Time.zone.today.year, 10, 18), "seasonal" ],
      [ "Black Friday", Date.new(Time.zone.today.year, 11, 27), "retail" ],
      [ "Navidad", Date.new(Time.zone.today.year, 12, 25), "holiday" ],
      [ "Año Nuevo", Date.new(Time.zone.today.year + 1, 1, 1), "holiday" ]
    ].each do |name, date, category|
      find_or_create_by!(name:, event_date: date, country: "AR") do |event|
        event.category = category
        event.active = true
      end
    end
  end
end
