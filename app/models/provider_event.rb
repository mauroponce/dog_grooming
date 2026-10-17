class ProviderEvent < ApplicationRecord
  belongs_to :business
  belongs_to :user, optional: true

  validates :event_type, :title, presence: true

  scope :for_business, ->(business) { where(business:) }
  scope :for_user, ->(user) { user.present? ? where(user_id: [ nil, user.id ]) : where(user_id: nil) }
  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
end
