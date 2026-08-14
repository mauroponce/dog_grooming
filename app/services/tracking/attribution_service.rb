module Tracking
  class AttributionService
    def self.track_visit(...)
      Sales::TrackVisit.new(...).call
    end

    def self.record_booking(...)
      Sales::RecordAttribution.new(...).call
    end
  end
end
