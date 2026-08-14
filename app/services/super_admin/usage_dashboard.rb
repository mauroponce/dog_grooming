module SuperAdmin
  class UsageDashboard
    FeatureRow = Struct.new(:feature, :calls, :tokens, :estimated_cost_usd, :errors, keyword_init: true)

    attr_reader :now

    def initialize(now: Time.current)
      @now = now
    end

    def gemini_available?
      Ai::GeminiClient.available?
    end

    def gemini_model
      Ai::GeminiClient.configured_model
    end

    def gemini_pricing_configured?
      Ai::UsageCostEstimator.configured?
    end

    def gemini_input_rate
      Ai::UsageCostEstimator.input_rate
    end

    def gemini_output_rate
      Ai::UsageCostEstimator.output_rate
    end

    def gemini_monthly_budget_usd
      BigDecimal(ENV.fetch("GEMINI_MONTHLY_BUDGET_USD", "0").to_s)
    rescue ArgumentError
      BigDecimal("0")
    end

    def gemini_summary
      {
        calls_today: gemini_scope.where(request_started_at: today_range).count,
        calls_month: gemini_scope.where(request_started_at: month_range).count,
        tokens_today: sum_for(gemini_scope.where(request_started_at: today_range), :total_tokens),
        tokens_month: sum_for(gemini_scope.where(request_started_at: month_range), :total_tokens),
        cost_today_usd: decimal_sum_for(gemini_scope.where(request_started_at: today_range), :estimated_cost_usd),
        cost_month_usd: decimal_sum_for(gemini_scope.where(request_started_at: month_range), :estimated_cost_usd),
        errors_today: gemini_scope.errored.where(request_started_at: today_range).count,
        errors_month: gemini_scope.errored.where(request_started_at: month_range).count
      }
    end

    def gemini_feature_rows
      gemini_scope.where(request_started_at: month_range)
        .group(:feature)
        .pluck(
          :feature,
          Arel.sql("COUNT(*)"),
          Arel.sql("COALESCE(SUM(total_tokens), 0)"),
          Arel.sql("COALESCE(SUM(estimated_cost_usd), 0)"),
          Arel.sql("SUM(CASE WHEN status = 'error' THEN 1 ELSE 0 END)")
        )
        .map do |feature, calls, tokens, cost, errors|
          FeatureRow.new(
            feature: feature,
            calls: calls.to_i,
            tokens: tokens.to_i,
            estimated_cost_usd: BigDecimal(cost.to_s),
            errors: errors.to_i
          )
        end
        .sort_by { |row| [ -row.estimated_cost_usd, -row.tokens, row.feature.to_s ] }
    end

    def recent_gemini_events
      gemini_scope.includes(:business).order(request_started_at: :desc).limit(12)
    end

    def storage_snapshot
      @storage_snapshot ||= SuperAdmin::Usage::StorageSnapshot.new.call
    end

    def r2_snapshot
      @r2_snapshot ||= SuperAdmin::Usage::R2AnalyticsClient.new.snapshot
    end

    private
      def gemini_scope
        return AiApiUsageEvent.none unless defined?(AiApiUsageEvent) && AiApiUsageEvent.table_exists?

        AiApiUsageEvent.gemini
      rescue ActiveRecord::StatementInvalid
        AiApiUsageEvent.none
      end

      def today_range
        now.beginning_of_day..now
      end

      def month_range
        now.beginning_of_month..now
      end

      def sum_for(scope, column)
        scope.sum(column).to_i
      end

      def decimal_sum_for(scope, column)
        BigDecimal(scope.sum(column).to_s)
      end
  end
end
