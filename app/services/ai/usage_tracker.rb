module Ai
  class UsageTracker
    class << self
      def record(provider:, feature:, model:, business: nil, request_started_at:, request_finished_at: Time.current,
        status:, prompt_tokens: 0, completion_tokens: 0, total_tokens: nil, error: nil, metadata: {})
        return unless storage_available?

        prompt_tokens = prompt_tokens.to_i.clamp(0, 2_147_483_647)
        completion_tokens = completion_tokens.to_i.clamp(0, 2_147_483_647)
        total_tokens = (total_tokens.presence || prompt_tokens + completion_tokens).to_i.clamp(0, 2_147_483_647)

        AiApiUsageEvent.create!(
          provider: provider.to_s.presence || "unknown",
          feature: feature.to_s.presence || "unknown",
          model: model.to_s.presence,
          business_id: business_id_for(business),
          request_started_at: request_started_at,
          request_finished_at: request_finished_at,
          status: status.to_s == "error" ? "error" : "success",
          error_class: error&.class&.name,
          error_message: error&.message.to_s.truncate(1_000).presence,
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens,
          total_tokens: total_tokens,
          estimated_cost_usd: Ai::UsageCostEstimator.estimate(
            prompt_tokens: prompt_tokens,
            completion_tokens: completion_tokens
          ),
          metadata: metadata.to_h
        )
      rescue StandardError => error
        Rails.logger.warn("AI usage tracking failed: #{error.class}: #{error.message}")
        nil
      end

      private
        def storage_available?
          defined?(AiApiUsageEvent) && AiApiUsageEvent.table_exists?
        rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
          false
        end

        def business_id_for(value)
          return value.id if value.respond_to?(:id)
          return value.to_i if value.present?

          nil
        end
    end
  end
end
