namespace :citapet do
  desc "Reinicia los datos previos al lanzamiento; ejecutar una sola vez con backup y workers detenidos"
  task reset_prelaunch: :environment do
    abort "Requiere RESET_PRELAUNCH_DATA=confirm-citapet-prelaunch" unless ENV["RESET_PRELAUNCH_DATA"] == "confirm-citapet-prelaunch"
    abort "Configurá SUPER_ADMIN_EMAIL y SUPER_ADMIN_PASSWORD antes de reiniciar" unless ENV["SUPER_ADMIN_EMAIL"].present? && ENV["SUPER_ADMIN_PASSWORD"].to_s.length >= 12

    connection = ActiveRecord::Base.connection
    connection.transaction do
      tables = connection.tables - %w[ar_internal_metadata schema_migrations]
      connection.execute("TRUNCATE TABLE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} RESTART IDENTITY CASCADE")
      User.create!(email_address: ENV.fetch("SUPER_ADMIN_EMAIL"), password: ENV.fetch("SUPER_ADMIN_PASSWORD"), role: :super_admin)
      ServiceCatalog::DefaultCatalog.seed!
    end
    puts "Datos previos al lanzamiento eliminados; catálogo y super admin inicializados."
  end
end
