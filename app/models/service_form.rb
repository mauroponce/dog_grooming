class ServiceForm < ApplicationRecord
  belongs_to :business
  belongs_to :service
  has_many :service_form_questions, -> { order(:position, :id) }, dependent: :destroy
  has_many :service_form_responses, dependent: :destroy

  accepts_nested_attributes_for :service_form_questions, allow_destroy: true

  validates :title, presence: true
  validate :service_belongs_to_business

  scope :active, -> { where(active: true) }

  def active_questions
    service_form_questions.order(:position, :id)
  end

  private
    def service_belongs_to_business
      return if service.blank? || business.blank? || service.business_id == business_id

      errors.add(:service, "no pertenece al negocio")
    end
end
