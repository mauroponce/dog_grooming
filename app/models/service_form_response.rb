class ServiceFormResponse < ApplicationRecord
  belongs_to :business
  belongs_to :appointment
  belongs_to :customer_profile
  belongs_to :service_form

  validates :answers, presence: true
  validate :records_belong_to_business
  validate :required_answers_present

  private
    def records_belong_to_business
      errors.add(:appointment, "no pertenece al negocio") if appointment.present? && appointment.business_id != business_id
      errors.add(:customer_profile, "no pertenece al negocio") if customer_profile.present? && customer_profile.business_id != business_id
      errors.add(:service_form, "no pertenece al negocio") if service_form.present? && service_form.business_id != business_id
    end

    def required_answers_present
      return if service_form.blank?

      service_form.service_form_questions.select(&:required?).each do |question|
        value = answers[question.id.to_s]
        errors.add(:answers, "falta responder #{question.label}") if value.blank?
      end
    end
end
