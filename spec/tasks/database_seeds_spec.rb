require "rails_helper"
require "open3"

RSpec.describe "Database seeds" do
  it "skips development demo data successfully in test" do
    stdout, stderr, status = Open3.capture3(
      { "RAILS_ENV" => "test" },
      "bin/rails",
      "db:seed",
      chdir: Rails.root.to_s
    )

    expect(status).to be_success, "Test seeds failed:\n#{stdout}\n#{stderr}"
    expect(stdout).not_to include("Datos demo listos")
    expect(Business.where(slug: %w[demo-patitas demo-trial demo-restringida])).to be_empty
  end

  it "keeps db:seed prohibited in production" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    expect {
      load Rails.root.join("db/seeds.rb")
    }.to raise_error(SystemExit, /db:seed solo está habilitado en development/)
  end
end
