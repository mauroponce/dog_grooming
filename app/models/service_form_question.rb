class ServiceFormQuestion < ApplicationRecord
  QUESTION_TYPES = %w[short_text long_text yes_no single_choice multiple_choice].freeze

  belongs_to :business
  belongs_to :service_form

  before_validation :inherit_business

  validates :label, :question_type, presence: true
  validates :question_type, inclusion: { in: QUESTION_TYPES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :form_belongs_to_business

  private
    def inherit_business
      self.business ||= service_form&.business
    end

    def form_belongs_to_business
      return if service_form.blank? || business.blank? || service_form.business_id == business_id

      errors.add(:service_form, "no pertenece al negocio")
    end
end
