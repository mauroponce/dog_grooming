module SuperAdmin
  class SyncBusinessAvailability
    DEFAULT_START_TIME = "10:00"
    DEFAULT_END_TIME = "19:00"

    def self.call(business, params)
      new(business, params).call
    end

    def initialize(business, params)
      @business = business
      @params = params || {}
    end

    def call
      return if params.blank?

      Business::DAYS.each do |weekday, _day_name|
        values = params[weekday.to_s] || params[weekday] || {}
        active = ActiveModel::Type::Boolean.new.cast(values["active"] || values[:active]) || false
        rule = business.availability_rules.find_or_initialize_by(weekday: weekday)
        rule.update!(
          active: active,
          start_time: active ? normalize_time(values["start_time"] || values[:start_time], DEFAULT_START_TIME) : DEFAULT_START_TIME,
          end_time: active ? normalize_time(values["end_time"] || values[:end_time], DEFAULT_END_TIME) : DEFAULT_END_TIME,
          break_start_time: active ? normalize_optional_time(values["break_start_time"] || values[:break_start_time]) : nil,
          break_end_time: active ? normalize_optional_time(values["break_end_time"] || values[:break_end_time]) : nil
        )
      end
    end

    private
      attr_reader :business, :params

      def normalize_time(value, fallback)
        normalize_optional_time(value).presence || fallback
      end

      def normalize_optional_time(value)
        raw_value = value.to_s.strip
        return nil unless raw_value.match?(/\A\d{1,2}:\d{2}\z/)

        hour, minute = raw_value.split(":").map(&:to_i)
        return nil unless hour.in?(0..23) && minute.in?(0..59)

        format("%02d:%02d", hour, minute)
      end
  end
end
