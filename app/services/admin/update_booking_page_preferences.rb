module Admin
  class UpdateBookingPagePreferences
    BOOLEAN = ActiveModel::Type::Boolean.new

    def self.call(business, params)
      new(business, params).call
    end

    def initialize(business, params)
      @business = business
      @params = params.to_h
    end

    def call
      business.update!(
        preferences: business.preferences.to_h.merge(normalized_preferences),
        rescheduling_notice_hours: rescheduling_notice_hours
      )
      business
    end

    private
      attr_reader :business, :params

      def normalized_preferences
        {
          "public_booking_allow_professional_selection" => BOOLEAN.cast(params["allow_professional_selection"] || params[:allow_professional_selection]),
          "public_booking_show_team_members" => BOOLEAN.cast(params["show_team_members"] || params[:show_team_members]),
          "public_booking_assignment_strategy" => Business.normalize_public_booking_assignment_strategy(params["assignment_strategy"] || params[:assignment_strategy])
        }
      end

      def rescheduling_notice_hours
        params.fetch("rescheduling_notice_hours", params.fetch(:rescheduling_notice_hours, business.rescheduling_notice_hours))
      end
  end
end
