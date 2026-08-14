require "net/http"

module SuperAdmin
  module Usage
    class R2AnalyticsClient
      GRAPHQL_URL = "https://api.cloudflare.com/client/v4/graphql"

      BucketSnapshot = Struct.new(:name, :payload_bytes, :metadata_bytes, :object_count, :upload_count, :requests_24h, :measured_at, keyword_init: true)

      def initialize(account_id: nil, api_token: nil, buckets: nil)
        @account_id = account_id.presence || ENV["CLOUDFLARE_ACCOUNT_ID"].presence
        @api_token = api_token.presence || ENV["CLOUDFLARE_R2_ANALYTICS_TOKEN"].presence || ENV["CLOUDFLARE_API_TOKEN"].presence
        @buckets = Array(buckets.presence || configured_buckets).compact_blank.uniq
      end

      def configured?
        account_id.present? && api_token.present? && buckets.any?
      end

      def snapshot
        return not_configured_snapshot unless configured?

        Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
          {
            configured: true,
            buckets: buckets.map { |bucket| bucket_snapshot(bucket) },
            error: nil,
            fetched_at: Time.current
          }
        end
      rescue StandardError => error
        Rails.logger.warn("Cloudflare R2 analytics failed: #{error.class}: #{error.message}")
        {
          configured: true,
          buckets: [],
          error: error.message,
          fetched_at: Time.current
        }
      end

      private
        attr_reader :account_id, :api_token, :buckets

        def configured_buckets
          [
            ENV["CLOUDFLARE_R2_BUCKET"].presence || ENV["R2_BUCKET"].presence,
            ENV["CLOUDFLARE_R2_SERVICE_IMAGES_BUCKET"].presence || ENV["SERVICE_IMAGES_BUCKET"].presence
          ]
        end

        def cache_key
          [ "super_admin", "r2_analytics", account_id, buckets.sort.join(":"), Time.zone.today.iso8601 ]
        end

        def bucket_snapshot(bucket)
          storage = latest_storage_for(bucket)
          operations = operations_for(bucket)

          BucketSnapshot.new(
            name: bucket,
            payload_bytes: storage.dig("max", "payloadSize").to_i,
            metadata_bytes: storage.dig("max", "metadataSize").to_i,
            object_count: storage.dig("max", "objectCount").to_i,
            upload_count: storage.dig("max", "uploadCount").to_i,
            requests_24h: operations.sum { |row| row.dig("sum", "requests").to_i },
            measured_at: parse_time(storage.dig("dimensions", "datetime"))
          )
        end

        def latest_storage_for(bucket)
          data = request_graphql(storage_query, bucket)
          Array(data.dig("viewer", "accounts", 0, "r2StorageAdaptiveGroups")).first || {}
        end

        def operations_for(bucket)
          data = request_graphql(operations_query, bucket, 24.hours.ago)
          Array(data.dig("viewer", "accounts", 0, "r2OperationsAdaptiveGroups"))
        end

        def request_graphql(query, bucket, start_date = 31.days.ago)
          uri = URI(GRAPHQL_URL)
          request = Net::HTTP::Post.new(uri)
          request["Authorization"] = "Bearer #{api_token}"
          request["Content-Type"] = "application/json"
          request.body = JSON.generate({
            query: query,
            variables: {
              accountTag: account_id,
              startDate: start_date.iso8601,
              endDate: Time.current.iso8601,
              bucketName: bucket
            }
          })

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 4, read_timeout: 8) { |http| http.request(request) }
          parsed = JSON.parse(response.body.presence || "{}")
          raise "Cloudflare GraphQL #{response.code}: #{parsed["errors"].presence || parsed}" unless response.is_a?(Net::HTTPSuccess) && parsed["errors"].blank?

          parsed.fetch("data", {})
        end

        def storage_query
          <<~GRAPHQL
            query R2StorageUsage($accountTag: string!, $startDate: Time, $endDate: Time, $bucketName: string) {
              viewer {
                accounts(filter: { accountTag: $accountTag }) {
                  r2StorageAdaptiveGroups(
                    limit: 1
                    filter: {
                      datetime_geq: $startDate
                      datetime_leq: $endDate
                      bucketName: $bucketName
                    }
                    orderBy: [datetime_DESC]
                  ) {
                    max {
                      objectCount
                      uploadCount
                      payloadSize
                      metadataSize
                    }
                    dimensions {
                      datetime
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        def operations_query
          <<~GRAPHQL
            query R2OperationsUsage($accountTag: string!, $startDate: Time, $endDate: Time, $bucketName: string) {
              viewer {
                accounts(filter: { accountTag: $accountTag }) {
                  r2OperationsAdaptiveGroups(
                    limit: 10000
                    filter: {
                      datetime_geq: $startDate
                      datetime_leq: $endDate
                      bucketName: $bucketName
                    }
                  ) {
                    sum {
                      requests
                    }
                    dimensions {
                      actionType
                    }
                  }
                }
              }
            }
          GRAPHQL
        end

        def parse_time(value)
          Time.zone.parse(value.to_s) if value.present?
        rescue ArgumentError
          nil
        end

        def not_configured_snapshot
          {
            configured: false,
            buckets: [],
            error: "Configurá CLOUDFLARE_ACCOUNT_ID y CLOUDFLARE_R2_ANALYTICS_TOKEN o CLOUDFLARE_API_TOKEN para consultar métricas oficiales.",
            fetched_at: Time.current
          }
        end
    end
  end
end
