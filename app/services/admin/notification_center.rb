module Admin
  class NotificationCenter
    DEFAULT_LIMIT = 8

    attr_reader :business, :current_user, :limit

    def initialize(business:, current_user:, limit: DEFAULT_LIMIT)
      @business = business
      @current_user = current_user
      @limit = limit
    end

    def items
      @items ||= events.map { |event| NotificationItem.new(event) }
    end

    def all_items(limit: nil)
      scope = events_scope.recent
      scope = scope.limit(limit) if limit.present?
      scope.map { |event| NotificationItem.new(event) }
    end

    def unread_count
      @unread_count ||= events_scope.unread.count
    end

    def unread_label
      "#{unread_count} sin leer"
    end

    def events_scope
      ProviderEvent.for_business(business)
    end

    private
      def events
        @events ||= events_scope.recent.limit(limit).to_a
      end
  end
end
