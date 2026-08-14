require "rails_helper"

RSpec.describe WhatsApp::OwnerNotification do
  describe ".supported_event_type?" do
    it "notifies the owner only for cancellations from the customer portal" do
      expect(described_class).to be_supported_event_type("customer_cancelled_booking")
      expect(described_class).not_to be_supported_event_type("booking_cancelled")
    end
  end
end
