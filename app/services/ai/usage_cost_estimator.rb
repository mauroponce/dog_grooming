module Ai
  class UsageCostEstimator
    class << self
      def estimate(prompt_tokens:, completion_tokens:)
        input_cost = BigDecimal(prompt_tokens.to_i.to_s) * input_rate / 1_000_000
        output_cost = BigDecimal(completion_tokens.to_i.to_s) * output_rate / 1_000_000
        (input_cost + output_cost).round(6)
      end

      def configured?
        input_rate.positive? || output_rate.positive?
      end

      def input_rate
        decimal_env("GEMINI_INPUT_USD_PER_1M_TOKENS")
      end

      def output_rate
        decimal_env("GEMINI_OUTPUT_USD_PER_1M_TOKENS")
      end

      private
        def decimal_env(key)
          BigDecimal(ENV.fetch(key, "0").to_s)
        rescue ArgumentError
          BigDecimal("0")
        end
    end
  end
end
