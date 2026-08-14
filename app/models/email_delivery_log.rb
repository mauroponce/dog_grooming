class EmailDeliveryLog < ApplicationRecord
  STATUSES = %w[queued sent failed skipped].freeze

  belongs_to :business, optional: true

  validates :recipient, :mailer, :action, :subject, :provider, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
end
