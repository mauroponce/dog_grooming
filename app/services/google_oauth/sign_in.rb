module GoogleOAuth
  class SignIn
    Result = Struct.new(:user, :reason, keyword_init: true) do
      def success? = user.present?
    end

    def self.call(...) = new(...).call

    def initialize(identity:)
      @identity = identity
    end

    def call
      user = User.transaction do
        User.lock.find_by(google_uid: identity.uid) || link_preprovisioned_user
      end

      return Result.new(reason: :not_found) unless user
      return Result.new(reason: :disabled) if user.disabled?

      user.update!(last_login_provider: "google")
      Result.new(user: user)
    rescue ActiveRecord::RecordNotUnique
      retry
    end

    private
      attr_reader :identity

      def link_preprovisioned_user
        user = User.lock.find_by(email_address: identity.email_address)
        return unless user

        user.update!(google_uid: identity.uid, google_connected_at: Time.current)
        user
      end
  end
end
