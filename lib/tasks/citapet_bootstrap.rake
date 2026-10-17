namespace :citapet do
  desc "Crea un superadmin sin modificar ningún otro dato"
  task bootstrap_super_admin: :environment do
    email = ENV.fetch("SUPER_ADMIN_EMAIL", "").to_s.strip.downcase
    abort "Definí SUPER_ADMIN_EMAIL." if email.blank?

    user = User.find_or_initialize_by(email_address: email)
    if user.persisted? && !user.super_admin?
      abort "Ya existe un usuario no-superadmin con SUPER_ADMIN_EMAIL=#{email}. No se modificó."
    end

    if user.new_record?
      user.assign_attributes(name: ENV.fetch("SUPER_ADMIN_NAME", "Superadmin Cita.pet"), role: :super_admin)
      user.save!
      puts "Superadmin creado: #{user.email_address}"
    else
      puts "Superadmin ya existente: #{user.email_address}"
    end
  end
end
