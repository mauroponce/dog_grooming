require "rails_helper"

RSpec.describe SuperAdmin::DashboardHelper, type: :helper do
  describe "#super_admin_time_ago" do
    it "renders elapsed time in Spanish" do
      expect(helper.super_admin_time_ago(3.hours.ago)).to eq("hace alrededor de 3 horas")
    end
  end
end
