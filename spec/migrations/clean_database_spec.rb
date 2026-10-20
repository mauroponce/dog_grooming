require "rails_helper"
require "open3"
require "pg"
require "uri"

RSpec.describe "Clean database migrations" do
  it "creates the current schema by running every migration on an empty database" do
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    database_name = "dog_grooming_migration_spec_#{SecureRandom.hex(6)}"
    admin_connection = PG.connect(
      host: config.fetch(:host),
      port: config.fetch(:port),
      user: config.fetch(:username),
      password: config.fetch(:password),
      dbname: "postgres"
    )
    admin_connection.exec("CREATE DATABASE #{PG::Connection.quote_ident(database_name)}")

    stdout, stderr, status = Open3.capture3(
      {
        "RAILS_ENV" => "test",
        "DATABASE_URL" => database_url(config, database_name)
      },
      "bin/rails",
      "db:migrate",
      chdir: Rails.root.to_s
    )

    expect(status).to be_success, "Clean migration failed:\n#{stdout}\n#{stderr}"
  ensure
    if admin_connection && database_name&.start_with?("dog_grooming_migration_spec_")
      admin_connection.exec_params(
        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()",
        [ database_name ]
      )
      admin_connection.exec("DROP DATABASE IF EXISTS #{PG::Connection.quote_ident(database_name)}")
      admin_connection.close
    end
  end

  def database_url(config, database_name)
    URI::Generic.build(
      scheme: "postgresql",
      userinfo: "#{URI.encode_uri_component(config.fetch(:username))}:#{URI.encode_uri_component(config.fetch(:password))}",
      host: config.fetch(:host),
      port: config.fetch(:port),
      path: "/#{database_name}"
    ).to_s
  end
end
