class AvailabilityBlock < ApplicationRecord
  Occurrence = Struct.new(
    :id,
    :series_id,
    :starts_at,
    :ends_at,
    :reason,
    :description,
    :block_type,
    :employee_membership_id,
    :bookable_resource_id,
    :online_booking_allowed,
    :recurrence,
    keyword_init: true
  ) do
    def duration_minutes
      [ ((ends_at - starts_at) / 60).round, 15 ].max
    end
  end

  BLOCK_TYPES = {
    "center_block" => "Bloqueo del centro",
    "professional_block" => "Bloqueo de profesional",
    "resource_block" => "Bloqueo de recurso",
    "vacation" => "Vacaciones",
    "holiday" => "Feriado",
    "non_working_period" => "Fecha no laborable",
    "internal_use" => "Uso interno",
    "maintenance" => "Mantenimiento",
    "lunch" => "Almuerzo",
    "absence" => "Ausencia",
    "other" => "Otro"
  }.freeze
  RECURRENCES = {
    "none" => "No se repite",
    "daily" => "Todos los días",
    "weekdays" => "De lunes a viernes",
    "weekly" => "Cada semana",
    "monthly" => "Cada mes"
  }.freeze

  belongs_to :business
  belongs_to :employee_membership, optional: true
  belongs_to :bookable_resource, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :starts_at, :ends_at, presence: true
  validates :block_type, inclusion: { in: BLOCK_TYPES.keys }
  validates :recurrence, inclusion: { in: RECURRENCES.keys }
  validate :ends_after_start
  validate :employee_belongs_to_business
  validate :resource_belongs_to_business
  validate :recurrence_end_after_start

  scope :active, -> { where(cancelled_at: nil) }
  scope :overlapping, ->(starts_at, ends_at) { where("starts_at < ? AND ends_at > ?", ends_at, starts_at) }
  scope :center_level, -> { where(employee_membership_id: nil, bookable_resource_id: nil) }
  scope :non_working_periods, -> { active.center_level.where(block_type: "non_working_period", recurrence: "none", online_booking_allowed: false) }

  after_commit :broadcast_realtime_updates_later, on: %i[create update destroy]

  def block_type_label
    BLOCK_TYPES.fetch(block_type, "Bloqueo")
  end

  def recurrence_label
    RECURRENCES.fetch(recurrence, RECURRENCES.fetch("none"))
  end

  def cancelled?
    cancelled_at.present?
  end

  def occurrence_id_for(date)
    "#{id}:#{date.to_date.iso8601}"
  end

  def occurrences_between(range_start, range_end)
    range_start = range_start.in_time_zone
    range_end = range_end.in_time_zone
    return [] unless starts_at.present? && ends_at.present?

    if recurrence == "none"
      return [] unless overlaps_interval?(starts_at, ends_at, range_start, range_end)

      return [ occurrence_for(starts_at.to_date, id.to_s) ]
    end

    first_date = [ starts_at.to_date, range_start.to_date ].max
    last_date = [ recurrence_ends_on || range_end.to_date, range_end.to_date ].min
    return [] if last_date < first_date

    (first_date..last_date).filter_map do |date|
      next unless occurs_on_date?(date)

      occurrence = occurrence_for(date, occurrence_id_for(date))
      occurrence if overlaps_interval?(occurrence.starts_at, occurrence.ends_at, range_start, range_end)
    end
  end

  def overlaps_time?(starts_at, ends_at)
    occurrences_between(starts_at, ends_at).any?
  end

  def self.occurrences_for(business:, starts_at:, ends_at:, include_online_bookable: true)
    relation = business.availability_blocks.active
    relation = relation.where(online_booking_allowed: false) unless include_online_bookable
    relation = relation.where(overlap_candidate_sql, range_start: starts_at, range_end: ends_at, range_start_date: starts_at.to_date)
    relation.flat_map { |block| block.occurrences_between(starts_at, ends_at) }.sort_by(&:starts_at)
  end

  def self.blocking_time?(business:, starts_at:, ends_at:, employee_membership: nil, bookable_resource: nil, online_booking: false)
    relation = business.availability_blocks.active
    relation = relation.where(online_booking_allowed: false) if online_booking
    relation = relation.where(overlap_candidate_sql, range_start: starts_at, range_end: ends_at, range_start_date: starts_at.to_date)

    relation = if bookable_resource.present?
      relation.where(bookable_resource_id: bookable_resource.id)
    elsif employee_membership.present?
      relation.where(bookable_resource_id: nil).where("employee_membership_id IS NULL OR employee_membership_id = ?", employee_membership.id)
    else
      relation.where(employee_membership_id: nil, bookable_resource_id: nil)
    end

    relation.any? { |block| block.overlaps_time?(starts_at, ends_at) }
  end

  private
    def self.overlap_candidate_sql
      <<~SQL.squish
        (
          recurrence = 'none'
          AND starts_at < :range_end
          AND ends_at > :range_start
        )
        OR
        (
          recurrence <> 'none'
          AND starts_at < :range_end
          AND (recurrence_ends_on IS NULL OR recurrence_ends_on >= :range_start_date)
        )
      SQL
    end

    def ends_after_start
      return if starts_at.blank? || ends_at.blank?

      errors.add(:ends_at, "debe ser posterior al inicio") if ends_at <= starts_at
    end

    def recurrence_end_after_start
      return if recurrence_ends_on.blank? || starts_at.blank?

      errors.add(:recurrence_ends_on, "debe ser posterior o igual a la fecha inicial") if recurrence_ends_on < starts_at.to_date
    end

    def employee_belongs_to_business
      return if employee_membership.blank? || business.blank? || employee_membership.business_id == business_id

      errors.add(:employee_membership, "debe pertenecer al mismo negocio")
    end

    def resource_belongs_to_business
      return if bookable_resource.blank? || business.blank? || bookable_resource.business_id == business_id

      errors.add(:bookable_resource, "debe pertenecer al mismo negocio")
    end

    def occurrence_for(date, occurrence_id)
      occurrence_starts_at = time_on_date(date, starts_at)
      Occurrence.new(
        id: occurrence_id,
        series_id: id.to_s,
        starts_at: occurrence_starts_at,
        ends_at: occurrence_starts_at + (ends_at - starts_at),
        reason: reason.presence || "No disponible",
        description: description,
        block_type: block_type,
        employee_membership_id: employee_membership_id,
        bookable_resource_id: bookable_resource_id,
        online_booking_allowed: online_booking_allowed,
        recurrence: recurrence
      )
    end

    def occurs_on_date?(date)
      return false if date < starts_at.to_date

      case recurrence
      when "daily"
        true
      when "weekdays"
        !date.saturday? && !date.sunday?
      when "weekly"
        date.wday == starts_at.wday
      when "monthly"
        date.day == starts_at.day
      else
        date == starts_at.to_date
      end
    end

    def time_on_date(date, value)
      zoned = value.in_time_zone
      Time.zone.local(date.year, date.month, date.day, zoned.hour, zoned.min, zoned.sec)
    end

    def overlaps_interval?(left_start, left_end, right_start, right_end)
      left_start < right_end && left_end > right_start
    end

    def broadcast_realtime_updates_later
      PublicBooking::BroadcastServicesJob.perform_later(business_id)
    end
end
