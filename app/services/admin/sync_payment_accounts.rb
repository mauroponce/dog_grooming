module Admin
  class SyncPaymentAccounts
    BOOLEAN = ActiveModel::Type::Boolean.new

    def self.call(business, params)
      new(business, params).call
    end

    def initialize(business, params)
      @business = business
      @params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    end

    def call
      processed_accounts = []
      items.each do |key, values|
        account = process_item!(values)
        processed_accounts << [ key.to_s, account ] if account.present?
      end

      normalize_primary_account!(processed_accounts)
      business.payment_accounts.reload
    end

    private
      attr_reader :business, :params

      def items
        params.fetch("items", {})
      end

      def primary_key
        params["primary_key"].to_s
      end

      def process_item!(values)
        attributes = values.respond_to?(:to_unsafe_h) ? values.to_unsafe_h : values.to_h
        return destroy_account!(attributes["id"]) if destroy_requested?(attributes)

        name = attributes["name"].to_s.squish
        details = attributes["details"].to_s.strip
        return if name.blank? && details.blank?

        raise ArgumentError, "Completá el nombre de la cuenta de cobro." if name.blank?
        raise ArgumentError, "Pegá los datos de la cuenta de cobro." if details.blank?

        account = attributes["id"].present? ? business.payment_accounts.find(attributes["id"]) : business.payment_accounts.build
        account.assign_attributes(name: name, details: details, active: true, primary_account: false)
        account.save!
        account
      end

      def destroy_account!(id)
        return if id.blank?

        business.payment_accounts.find(id).destroy!
        nil
      end

      def destroy_requested?(attributes)
        BOOLEAN.cast(attributes["_destroy"])
      end

      def normalize_primary_account!(processed_accounts)
        active_accounts = business.payment_accounts.active.ordered.to_a
        return if active_accounts.empty?

        selected_account = processed_accounts.find { |key, _account| key == primary_key }&.last
        selected_account = nil unless selected_account&.persisted? && selected_account.active?
        selected_account ||= active_accounts.find(&:primary_account?)
        selected_account ||= active_accounts.first

        business.payment_accounts.where.not(id: selected_account.id).update_all(primary_account: false, updated_at: Time.current)
        selected_account.update!(primary_account: true) unless selected_account.primary_account?
      end
  end
end
