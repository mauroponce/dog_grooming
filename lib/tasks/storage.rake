namespace :storage do
  desc "Purge old unattached Active Storage blobs from their configured storage service"
  task purge_unattached: :environment do
    number_helper = ActiveSupport::NumberHelper

    env_integer = lambda do |name, default|
      value = ENV[name].presence
      next default if value.blank?

      Integer(value)
    rescue ArgumentError
      abort "#{name} debe ser un entero."
    end

    older_than_hours = env_integer.call("OLDER_THAN_HOURS", 24)
    limit = env_integer.call("LIMIT", nil)
    dry_run = !ActiveModel::Type::Boolean.new.cast(ENV["CONFIRM"])

    result = Storage::PurgeUnattachedBlobs.new(
      older_than: older_than_hours.hours,
      dry_run: dry_run,
      limit: limit
    ).call

    puts "Entorno Rails: #{Rails.env}"
    puts "Servicio activo: #{Rails.application.config.active_storage.service}"
    puts "Modo: #{dry_run ? "simulación" : "borrado real"}"
    puts "Corte: blobs sin adjuntos creados antes de #{I18n.l(result.cutoff, format: :long)}"
    puts "Objetos encontrados: #{result.matched_count}"
    puts "Tamaño encontrado: #{number_helper.number_to_human_size(result.matched_bytes)}"

    if result.services.present?
      puts "Por servicio:"
      result.services.values.sort_by(&:name).each do |service|
        puts "- #{service.name}: #{service.objects} objetos, #{number_helper.number_to_human_size(service.bytes)}"
      end
    end

    puts "Objetos purgados: #{result.purged_count}" unless dry_run

    if result.errors.present?
      warn "Errores:"
      result.errors.each do |error|
        warn "- blob_id=#{error.blob_id} service=#{error.service_name} key=#{error.key}: #{error.message}"
      end
      abort "La limpieza terminó con errores."
    end

    if dry_run
      puts "No se borró nada. Ejecutá con CONFIRM=1 para purgar los objetos listados."
    end
  end
end
