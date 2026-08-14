class NotificationDelivery < ApplicationRecord
  belongs_to :business
  belongs_to :appointment, optional: true

  validates :channel, :recipient, :template, :status, presence: true
end
