require "rails_helper"

RSpec.describe Billing::DailyProcessor do
  it "notifies by email without sending an automatic WhatsApp when a trial reaches its payment date" do
    business = create_business
    business.update!(trial_ends_at: Time.current)
    mail_delivery = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    whatsapp_notifier = class_double(Billing::WhatsAppNotifier)
    allow(BillingMailer).to receive(:reminder).and_return(mail_delivery)
    allow(whatsapp_notifier).to receive(:call).and_return(
      Billing::WhatsAppNotifier::Result.new(status: :sent, recipient: "5491155551234")
    )

    described_class.new(today: Time.zone.today, whatsapp_notifier: whatsapp_notifier).call

    invoice = business.subscription.reload.current_invoice
    expect(invoice).to be_present
    expect(invoice.due_on).to eq(Time.zone.today)
    expect(BillingMailer).to have_received(:reminder).with(invoice, "due_today")
    expect(mail_delivery).to have_received(:deliver_later)
    expect(whatsapp_notifier).not_to have_received(:call)
    expect(invoice.billing_reminders.find_by!(reminder_type: "due_today", channel: "email")).to be_sent
    expect(invoice.billing_reminders.find_by(reminder_type: "due_today", channel: "whatsapp")).to be_nil
  end

  private
    def create_business
      owner = User.create!(
        email_address: "daily-billing-owner-#{SecureRandom.hex(4)}@example.com",
        password: "password123",
        role: :admin
      )
      Business.create!(
        owner: owner,
        name: "Centro Daily Billing",
        slug: "centro-daily-billing-#{SecureRandom.hex(4)}",
        contact_phone: "+54 9 11 5555-1234",
        onboarding_completed_at: Time.current
      )
    end
end
