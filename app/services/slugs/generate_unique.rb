module Slugs
  class GenerateUnique
    RESERVED_WORDS = %w[
      acceso admin api assets auth billing calendario comprobantes contacto dashboard demo depositos
      invitaciones login negocios onboarding passwords pricing privacy rails registro session signup
      soporte super-admin superadmin terms users webhooks
    ].freeze
    FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
    MIN_LENGTH = 3
    MAX_LENGTH = 60

    def self.call(base, scope:, current_record: nil, reserved_words: RESERVED_WORDS)
      new(base, scope: scope, current_record: current_record, reserved_words: reserved_words).call
    end

    def self.normalize(value)
      slug = I18n.transliterate(value.to_s)
        .downcase
        .gsub(/[^a-z0-9]+/, "-")
        .gsub(/-+/, "-")
        .gsub(/\A-|-+\z/, "")

      truncate(slug.presence || "centro")
    end

    def self.valid?(slug, reserved_words: RESERVED_WORDS)
      value = slug.to_s
      value.length.between?(MIN_LENGTH, MAX_LENGTH) &&
        value.match?(FORMAT) &&
        !reserved_words.include?(value.downcase)
    end

    def self.available?(slug, scope:, current_record: nil, reserved_words: RESERVED_WORDS)
      return false unless valid?(slug, reserved_words: reserved_words)

      relation = scope.where("LOWER(slug) = ?", slug.downcase)
      relation = relation.where.not(id: current_record.id) if current_record&.persisted?
      !relation.exists?
    end

    def self.truncate(slug, suffix = "")
      max_root_length = MAX_LENGTH - suffix.length
      root = slug.to_s.first(max_root_length).gsub(/-+\z/, "")
      root = "centro".first(max_root_length) if root.blank?
      "#{root}#{suffix}"
    end

    attr_reader :base, :scope, :current_record, :reserved_words

    def initialize(base, scope:, current_record: nil, reserved_words: RESERVED_WORDS)
      @base = self.class.normalize(base)
      @scope = scope
      @current_record = current_record
      @reserved_words = reserved_words
    end

    def call
      candidate = base
      counter = 2

      until self.class.available?(candidate, scope: scope, current_record: current_record, reserved_words: reserved_words)
        suffix = "-#{counter}"
        candidate = self.class.truncate(base, suffix)
        counter += 1
      end

      candidate
    end
  end
end
