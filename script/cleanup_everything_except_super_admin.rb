# frozen_string_literal: true

# Run it inside Docker with:
#   docker compose exec -T web bash -lc 'bin/rails runner script/cleanup_everything_except_super_admin.rb'

protected_email = ENV.fetch("SUPER_ADMIN_EMAIL", "admin@dog-grooming.test").strip.downcase
connection = ActiveRecord::Base.connection
database_name = connection.current_database

unless User.exists?(email_address: protected_email)
  abort "No existe ninguna cuenta de super admin con email #{protected_email}."
end

preserved_tables = %w[users schema_migrations ar_internal_metadata]
tables_to_truncate = connection.tables - preserved_tables

puts "Protegiendo #{protected_email}"
puts "Cerrando conexiones activas a #{database_name}..."
connection.execute(<<~SQL.squish)
  SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
  WHERE datname = #{connection.quote(database_name)}
    AND pid <> pg_backend_pid()
SQL

puts "Vaciando #{tables_to_truncate.size} tablas..."
connection.execute("SET lock_timeout = '5s'")

ActiveRecord::Base.transaction do
  if tables_to_truncate.any?
    quoted_tables = tables_to_truncate.map { |table| connection.quote_table_name(table) }.join(", ")
    connection.execute("TRUNCATE TABLE #{quoted_tables} RESTART IDENTITY CASCADE")
  end

  deleted_users = User.where.not(email_address: protected_email).delete_all
  puts "Usuarios eliminados: #{deleted_users}"
end

puts "Listo. Solo quedó la cuenta #{protected_email}."
