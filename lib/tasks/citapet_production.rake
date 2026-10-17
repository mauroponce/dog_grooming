namespace :citapet do
  desc "Valida la configuración obligatoria antes de migrar o iniciar producción"
  task production_preflight: :environment do
    abort "Esta verificación solo se ejecuta con RAILS_ENV=production." unless Rails.env.production?

    required = %w[
      SECRET_KEY_BASE
      DOG_GROOMING_DATABASE_PASSWORD
      APP_HOST
      GOOGLE_CLIENT_ID
      GOOGLE_CLIENT_SECRET
      RESEND_API_KEY
      CLOUDFLARE_ACCESS_KEY_ID
      CLOUDFLARE_SECRET_ACCESS_KEY
      CLOUDFLARE_R2_ENDPOINT
      CLOUDFLARE_R2_BUCKET
      CLOUDFLARE_R2_SERVICE_IMAGES_BUCKET
    ]
    missing = required.select { |name| ENV[name].blank? }
    abort "Faltan variables obligatorias: #{missing.join(', ')}" if missing.any?

    abort "APP_HOST debe ser cita.pet para el lanzamiento inicial." unless Business.normalize_custom_domain(ENV.fetch("APP_HOST")) == "cita.pet"
    abort "ACTIVE_STORAGE_SERVICE debe ser r2 en producción." unless Rails.application.config.active_storage.service.to_s == "r2"

    puts "Preflight de producción correcto. No se ejecutaron seeds ni se mostraron secretos."
  end
end
