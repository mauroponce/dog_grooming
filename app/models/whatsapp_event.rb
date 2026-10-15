class WhatsAppEvent < ApplicationRecord
  belongs_to :business
  after_create_commit -> { WhatsApp::ProcessEventJob.perform_later(id) }
end
