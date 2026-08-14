require "net/http"
require "base64"
require "cgi"
require "langchain"
require "langchain/llm/google_gemini"

module Ai
  class GeminiClient
    DEFAULT_MODEL = "gemini-flash-lite-latest"

    class << self
      def available?
        api_key.present?
      end

      def configured_model
        model
      end

      def chat_text(system:, messages:, temperature: 0.4, max_tokens: 1_000, response_format: nil, model: nil, feature: "unknown", business: nil)
        raise "GEMINI_API_KEY no configurada" unless available?

        errors = []
        input_for_usage = usage_text(system, messages)
        model_candidates(model).each do |candidate_model|
          started_at = Time.current
          begin
            response = llm(model: candidate_model, temperature:).chat(
              messages: gemini_messages(messages),
              model: candidate_model,
              system: system,
              temperature: temperature,
              max_tokens: max_tokens,
              response_format: response_format
            )

            output = response.chat_completion.to_s.strip
            record_usage(
              feature: feature,
              business: business,
              model: candidate_model,
              started_at: started_at,
              input_text: input_for_usage,
              output_text: output,
              metadata: { method: "chat_text", estimated_tokens: true }
            )
            return output
          rescue StandardError => error
            record_usage(
              feature: feature,
              business: business,
              model: candidate_model,
              started_at: started_at,
              status: "error",
              input_text: input_for_usage,
              error: error,
              metadata: { method: "chat_text", estimated_tokens: true }
            )
            errors << "#{candidate_model}: #{error.message.truncate(240)}"
          end
        end

        raise errors.join(" | ")
      end

      def chat_json(system:, messages:, temperature: 0.3, max_tokens: 900, model: nil, feature: "unknown", business: nil)
        raw = chat_text(
          system: system,
          messages: messages,
          temperature: temperature,
          max_tokens: max_tokens,
          response_format: "application/json",
          model: model,
          feature: feature,
          business: business
        )
        parse_json(raw)
      rescue JSON::ParserError => error
        Rails.logger.warn("Gemini JSON parse failed: #{error.message}")
        {}
      end

      def generate_content_json(system:, prompt:, inline_data:, mime_type:, temperature: 0.1, max_tokens: 1_200, model: nil, feature: "unknown", business: nil)
        raw = generate_content_text(
          system: system,
          prompt: prompt,
          inline_data: inline_data,
          mime_type: mime_type,
          temperature: temperature,
          max_tokens: max_tokens,
          model: model,
          feature: feature,
          business: business
        )
        parse_json(raw)
      rescue JSON::ParserError => error
        Rails.logger.warn("Gemini multimodal JSON parse failed: #{error.message}")
        {}
      end

      def function_calls(system:, messages:, tools:, temperature: 0.0, feature: "unknown", business: nil)
        raise "GEMINI_API_KEY no configurada" unless available?

        errors = []
        input = interaction_input(system:, messages:)
        function_model_candidates.each do |candidate_model|
          started_at = Time.current
          begin
            response = post_interaction(
              model: candidate_model,
              input: input,
              tools: tools,
              temperature: temperature
            )
            calls = extract_function_calls(response)
            record_usage(
              feature: feature,
              business: business,
              model: candidate_model,
              started_at: started_at,
              input_text: [ input, tools.to_json ].join("\n"),
              output_text: response.to_json,
              usage: response["usage"],
              metadata: { method: "interactions", tool_calls: calls.size }
            )
            return calls if calls.any?
          rescue StandardError => error
            record_usage(
              feature: feature,
              business: business,
              model: candidate_model,
              started_at: started_at,
              status: "error",
              input_text: [ input, tools.to_json ].join("\n"),
              error: error,
              metadata: { method: "interactions", estimated_tokens: true }
            )
            errors << "#{candidate_model}: #{error.message.truncate(240)}"
          end
        end

        Rails.logger.warn("Gemini function calling returned no calls: #{errors.join(' | ')}") if errors.any?
        []
      end

      private
        INTERACTIONS_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"
        GENERATE_CONTENT_URL = "https://generativelanguage.googleapis.com/v1beta/models/%<model>s:generateContent"

        def llm(model:, temperature:)
          Langchain.logger.level = Logger::INFO if Langchain.respond_to?(:logger) && Langchain.logger
          Langchain::LLM::GoogleGemini.new(
            api_key: api_key,
            default_options: {
              chat_model: model,
              temperature: temperature
            }
          )
        end

        def api_key
          ENV["GEMINI_API_KEY"].presence || ENV["GOOGLE_GEMINI_API_KEY"].presence
        end

        def model
          ENV.fetch("GEMINI_MODEL", DEFAULT_MODEL)
        end

        def function_model
          ENV.fetch("GEMINI_FUNCTION_MODEL", model)
        end

        def multimodal_model
          ENV.fetch("GEMINI_RECEIPT_MODEL", model)
        end

        def model_candidates(preferred_model = nil)
          [ preferred_model, model, DEFAULT_MODEL ].compact.uniq
        end

        def multimodal_model_candidates(preferred_model = nil)
          [ preferred_model, multimodal_model, model, DEFAULT_MODEL, "gemini-2.5-flash" ].compact.uniq
        end

        def function_model_candidates
          [ function_model, model, DEFAULT_MODEL, "gemini-3-flash-preview" ].uniq
        end

        def gemini_messages(messages)
          Array(messages).map do |message|
            {
              role: gemini_role(message.fetch(:role).to_s),
              parts: [ { text: message.fetch(:content).to_s.truncate(12_000) } ]
            }
          end
        end

        def gemini_role(role)
          role == "assistant" ? "model" : role.in?(%w[user model]) ? role : "user"
        end

        def parse_json(raw)
          cleaned = raw.to_s.strip
          cleaned = cleaned.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
          JSON.parse(cleaned)
        end

        def generate_content_text(system:, prompt:, inline_data:, mime_type:, temperature:, max_tokens:, model:, feature:, business:)
          raise "GEMINI_API_KEY no configurada" unless available?

          errors = []
          input_for_usage = [ system, prompt ].join("\n")
          multimodal_model_candidates(model).each do |candidate_model|
            started_at = Time.current
            begin
              response = post_generate_content(
                model: candidate_model,
                system: system,
                prompt: prompt,
                inline_data: inline_data,
                mime_type: mime_type,
                temperature: temperature,
                max_tokens: max_tokens
              )
              text = response.dig("candidates", 0, "content", "parts").to_a.filter_map { |part| part["text"] }.join("\n").strip
              if text.present?
                record_usage(
                  feature: feature,
                  business: business,
                  model: candidate_model,
                  started_at: started_at,
                  input_text: input_for_usage,
                  output_text: text,
                  usage: response["usageMetadata"],
                  metadata: { method: "generate_content", mime_type: mime_type, inline_bytes: inline_data.to_s.bytesize }
                )
                return text
              end
            rescue StandardError => error
              record_usage(
                feature: feature,
                business: business,
                model: candidate_model,
                started_at: started_at,
                status: "error",
                input_text: input_for_usage,
                error: error,
                metadata: { method: "generate_content", mime_type: mime_type, estimated_tokens: true, inline_bytes: inline_data.to_s.bytesize }
              )
              errors << "#{candidate_model}: #{error.message.truncate(240)}"
            end
          end

          raise errors.join(" | ").presence || "Gemini no devolvió contenido"
        end

        def usage_text(system, messages)
          [
            system.to_s,
            Array(messages).map { |message| "#{message[:role] || message["role"]}: #{message[:content] || message["content"]}" }.join("\n")
          ].join("\n")
        end

        def record_usage(feature:, business:, model:, started_at:, status: "success", input_text: "", output_text: "", usage: nil, error: nil, metadata: {})
          prompt_tokens, completion_tokens, total_tokens, estimated = usage_counts(
            usage: usage,
            input_text: input_text,
            output_text: output_text
          )

          Ai::UsageTracker.record(
            provider: "gemini",
            feature: feature,
            model: model,
            business: business,
            request_started_at: started_at,
            request_finished_at: Time.current,
            status: status,
            prompt_tokens: prompt_tokens,
            completion_tokens: completion_tokens,
            total_tokens: total_tokens,
            error: error,
            metadata: metadata.merge(estimated_tokens: estimated)
          )
        end

        def usage_counts(usage:, input_text:, output_text:)
          usage = usage.respond_to?(:to_h) ? usage.to_h : {}
          prompt_tokens = integer_usage_value(usage, "promptTokenCount", "total_input_tokens", "totalInputTokens", "inputTokenCount")
          completion_tokens = integer_usage_value(usage, "candidatesTokenCount", "total_output_tokens", "totalOutputTokens", "outputTokenCount")
          total_tokens = integer_usage_value(usage, "totalTokenCount", "total_tokens", "totalTokens")
          estimated = false

          if prompt_tokens.zero? && completion_tokens.zero? && total_tokens.zero?
            prompt_tokens = estimated_tokens(input_text)
            completion_tokens = estimated_tokens(output_text)
            total_tokens = prompt_tokens + completion_tokens
            estimated = true
          elsif total_tokens.zero?
            total_tokens = prompt_tokens + completion_tokens
          end

          [ prompt_tokens, completion_tokens, total_tokens, estimated ]
        end

        def integer_usage_value(usage, *keys)
          keys.lazy.map { |key| usage[key] || usage[key.to_s] }.find(&:present?).to_i
        end

        def estimated_tokens(value)
          (value.to_s.length / 4.0).ceil
        end

        def interaction_input(system:, messages:)
          history = Array(messages).last(8).map do |message|
            role = message.fetch(:role).to_s == "model" || message.fetch(:role).to_s == "assistant" ? "Asistente" : "Usuario"
            "#{role}: #{message.fetch(:content).to_s.truncate(1_500)}"
          end.join("\n")

          [
            system,
            "Historial reciente:",
            history.presence || "Sin historial previo.",
            "Respondé este ultimo turno siguiendo las herramientas disponibles."
          ].join("\n\n")
        end

        def post_interaction(model:, input:, tools:, temperature:)
          uri = URI(INTERACTIONS_URL)
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request["x-goog-api-key"] = api_key
          request.body = JSON.generate({
            model: model,
            input: input,
            tools: tools,
            generation_config: {
              temperature: temperature,
              tool_choice: "auto"
            }
          })

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
          parsed = JSON.parse(response.body.presence || "{}")
          return parsed if response.is_a?(Net::HTTPSuccess)

          raise "Gemini interactions error #{response.code}: #{parsed}"
        end

        def post_generate_content(model:, system:, prompt:, inline_data:, mime_type:, temperature:, max_tokens:)
          uri = URI(format(GENERATE_CONTENT_URL, model: CGI.escape(model)))
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request["x-goog-api-key"] = api_key
          request.body = JSON.generate({
            systemInstruction: {
              parts: [ { text: system } ]
            },
            contents: [
              {
                role: "user",
                parts: [
                  { text: prompt },
                  {
                    inline_data: {
                      mime_type: mime_type,
                      data: Base64.strict_encode64(inline_data.to_s)
                    }
                  }
                ]
              }
            ],
            generationConfig: {
              temperature: temperature,
              maxOutputTokens: max_tokens,
              responseMimeType: "application/json"
            }
          })

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 8, read_timeout: 45) { |http| http.request(request) }
          parsed = JSON.parse(response.body.presence || "{}")
          return parsed if response.is_a?(Net::HTTPSuccess)

          raise "Gemini generateContent error #{response.code}: #{parsed}"
        end

        def extract_function_calls(response)
          Array(response["steps"]).filter_map do |step|
            next unless step["type"] == "function_call"

            {
              name: step["name"].to_s,
              arguments: step["arguments"].presence || {}
            }
          end
        end
    end
  end
end
