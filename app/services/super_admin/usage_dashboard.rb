module SuperAdmin
  class UsageDashboard
    attr_reader :now

    def initialize(now: Time.current)
      @now = now
    end

    def storage_snapshot
      @storage_snapshot ||= SuperAdmin::Usage::StorageSnapshot.new.call
    end

    def r2_snapshot
      @r2_snapshot ||= SuperAdmin::Usage::R2AnalyticsClient.new.snapshot
    end

    private
  end
end
