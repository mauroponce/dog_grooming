class ServicePack < ApplicationRecord
  belongs_to :business
  belongs_to :service, optional: true
  has_many :customer_packs, dependent: :restrict_with_error

  validates :name, :sessions_count, presence: true
  validates :sessions_count, numericality: { only_integer: true, greater_than: 0 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :service_belongs_to_business

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(active: :desc, name: :asc) }

  def price_label
    price_cents.present? ? "$#{ActiveSupport::NumberHelper.number_to_delimited(price_cents.to_i / 100, delimiter: ".")}" : "Consultar"
  end

  private
    def service_belongs_to_business
      return if service.blank? || business.blank? || service.business_id == business_id

      errors.add(:service, "no pertenece al negocio")
    end
end
