Rails.application.routes.draw do
  get "internal/caddy/tls-permission" => "internal/caddy#tls_permission"
  mount ActionCable.server => "/cable"

  get "acceder" => "sessions#new", as: :new_session
  resource :session, only: %i[create destroy]
  resources :passwords, param: :token
  get "acceso" => "magic_links#new", as: :new_magic_link
  post "acceso" => "magic_links#create", as: :magic_links
  get "acceso/:token" => "magic_links#show", as: :magic_link

  constraints CustomDomainConstraint.new do
    get "/" => "public_booking#show", as: :custom_public_business
    get "calendar.ics" => "public_booking#calendar", as: :custom_public_booking_calendar, defaults: { format: :ics }
    post "chat" => "chats#create", as: :custom_center_chat
    post "lista-de-espera" => "waitlist_entries#create", as: :custom_public_waitlist_entries
    get "servicios" => "public_service_pages#index", as: :custom_public_services
    get "servicios/:service_slug" => "public_service_pages#show", as: :custom_public_service
    get "promos" => "public_service_pages#promos", as: :custom_public_promos
    get "reservar" => "public_booking#new", as: :new_custom_public_booking
    post "reservar" => "public_booking#create", as: :custom_public_bookings

    get "mis-turnos" => "customer_portal/sessions#new", as: :custom_customer_portal_entry
    post "mis-turnos" => "customer_portal/sessions#create"
    get "mis-turnos/acceder/:token" => "customer_portal/sessions#show", as: :custom_customer_portal_access
    get "mis-turnos/panel" => "customer_portal/dashboard#show", as: :custom_customer_portal_dashboard
    patch "mis-turnos/panel" => "customer_portal/dashboard#update", as: :custom_customer_portal_dashboard_update
    delete "mis-turnos/salir" => "customer_portal/sessions#destroy", as: :custom_customer_portal_logout
    get "mis-turnos/:token" => "customer_portal/sessions#profile", as: :custom_customer_portal_profile_access
    get "turno/:token" => "customer_portal/bookings#show", as: :custom_customer_portal_short_booking
    get "mis-turnos/reserva/:token" => "customer_portal/bookings#show", as: :custom_customer_portal_booking
    get "mis-turnos/reserva/:token/reprogramar/disponibilidad" => "customer_portal/bookings#reschedule_availability", as: :custom_customer_portal_booking_reschedule_availability
    post "mis-turnos/reserva/:token/comprobante" => "customer_portal/bookings#upload_receipt", as: :custom_customer_portal_booking_receipt
    post "mis-turnos/reserva/:token/reprogramar" => "customer_portal/bookings#request_reschedule", as: :custom_customer_portal_booking_reschedule
    post "mis-turnos/reserva/:token/cancelar" => "customer_portal/bookings#cancel", as: :custom_customer_portal_booking_cancel

    get ":category_slug/:service_slug" => "public_booking#new", as: :custom_public_category_service
    get ":category_slug" => "public_service_pages#category", as: :custom_public_category, constraints: PublicCategoryConstraint.new(custom_domain: true)
  end

  root "home#index"

  get "registro/sugerencias-slug" => "home#registration_closed_json", as: :registro_slug_suggestions
  get "registro/disponibilidad-slug" => "home#registration_closed_json", as: :registro_slug_availability
  get "registro" => "registrations#new", as: :registro
  post "registro" => "registrations#create"
  get "registro/listo" => redirect("/")

  get "signup/slug_suggestions" => "home#registration_closed_json"
  get "signup/slug_availability" => "home#registration_closed_json"
  get "signup" => redirect("/registro")
  post "signup" => "registrations#create"
  get "signup/listo" => redirect("/registro")

  get "onboarding/horarios" => "onboarding#schedule", as: :onboarding_schedule
  patch "onboarding/horarios" => "onboarding#update_schedule"
  get "onboarding/servicio" => "onboarding#service", as: :onboarding_service
  post "onboarding/servicio" => "onboarding#create_service"
  get "onboarding/listo" => "onboarding#done", as: :onboarding_done

  namespace :admin do
    scope path_names: { new: "nuevo", edit: "editar" } do
      root "home#show"
      get "inicio" => "home#show", as: :home
      post "inicio/oportunidades/contactos" => "home_opportunities#create", as: :home_opportunity_contacts
      get "asistente" => "dashboard#show", as: :dashboard
      resources :assistant_messages, only: :create, path: "asistente/mensajes"
      resource :billing, only: :show, path: "suscripcion", controller: "billing" do
        post :upload_payment_proof, path: "comprobante"
        post :subscribe, path: "suscribirse"
      end
      resource :mercado_pago_connection, only: [], path: "configuracion/mercadopago", controller: "mercado_pago_connections" do
        get :connect, path: "conectar"
        get :callback
        delete :destroy, path: "desvincular"
      end
      get "mercado-pago/conectar" => "mercado_pago_connections#connect"
      get "mercado-pago/callback" => "mercado_pago_connections#callback"
      delete "mercado-pago/desvincular" => "mercado_pago_connections#destroy"
      resource :profile, only: %i[edit update], path: "perfil", controller: "profiles"
      delete "perfil/foto" => "profiles#destroy_photo", as: :profile_photo
      resource :settings, only: %i[show update], path: "configuracion", controller: "settings"
      get "tutoriales" => "tutorials#show", as: :tutorials
      resources :non_working_periods, only: %i[create destroy], path: "configuracion/fechas-no-laborables"
      resources :notifications, only: %i[destroy], path: "notificaciones" do
        collection do
          patch :mark_all_read, path: "marcar-todas-leidas"
        end
        member do
          patch :mark_read, path: "marcar-leida"
        end
      end
      get "calendario" => "calendar#show", as: :calendar
      get "turnos" => redirect("/admin/calendario", status: 302)
      get "lista-de-espera" => redirect("/admin/calendario?waitlist=1", status: 302)
      get "calendario/reservas/:short_uuid/detalle" => "appointments#details", as: :appointment_details
      resources :availability_blocks, only: %i[create destroy], path: "calendario/horarios-no-disponibles"
      delete "calendario/reservas/:short_uuid/eliminar" => "appointments#destroy", as: :destroy_appointment
      resources :appointments, only: :create, path: "calendario/reservas", param: :short_uuid do
        member do
          patch :confirm, path: "confirmar"
          patch :approve_deposit, path: "aprobar-comprobante"
          get :available_professionals, path: "profesionales-disponibles"
          patch :change_professional, path: "cambiar-profesional"
          patch :mark_remaining_balance_paid, path: "marcar-saldo-pagado"
          patch :update_notes, path: "notas"
          patch :cancel, path: "cancelar"
          patch :reject_deposit, path: "rechazar-comprobante"
          get :download_receipt, path: "descargar-comprobante"
          patch :upload_receipt, path: "subir-comprobante"
          patch :finalize, path: "finalizar"
        end
      end
      resources :services, path: "servicios" do
        collection do
          post :generate_description, path: "generar-descripcion"
        end

        member do
          post :duplicate, path: "duplicar"
          delete :destroy_image, path: "imagenes/:attachment_id"
          delete :permanently_destroy, path: "eliminar-permanentemente"
        end
      end
      post "servicios/extras", to: "extras#create", as: :service_extras
      patch "servicios/extras/:id", to: "extras#update", as: :service_extra
      resources :waitlist_entries, only: %i[create update destroy], path: "calendario/lista-de-espera"
      resources :service_categories, only: %i[create update destroy], path: "categorias-servicios"
      resources :employee_memberships, only: %i[index new create edit update destroy], path: "equipo", path_names: { new: "nuevo-miembro" } do
        member do
          patch :update_role, path: "rol"
          post :resend, path: "reenviar"
          patch :reactivate, path: "reactivar"
          delete :permanently_destroy, path: "eliminar"
        end
      end
      resources :customer_profiles, only: %i[index show new create edit update destroy], path: "clientes", path_names: { new: "nuevo", edit: "editar" } do
        collection do
          get :autocomplete, path: "buscar"
        end
        member do
          get :panel, path: "panel"
          patch :block, path: "bloquear"
          patch :unblock, path: "desbloquear"
          post :send_portal_access, path: "enviar-acceso"
          delete :destroy_photo, path: "fotos/:attachment_id"
        end
        resources :client_notes, only: :create, path: "notas"
        resources :customer_reminders, only: :create, path: "recordatorios" do
          member do
            patch :resolve, path: "resolver"
          end
        end
      end
    end
  end

  direct :admin_appointment do |appointment = nil, options = {}|
    calendar_options = options.dup
    if appointment.respond_to?(:starts_at) && appointment.starts_at.present? && !calendar_options.key?(:date)
      calendar_options[:date] = appointment.starts_at.to_date.iso8601
    end
    if appointment.respond_to?(:short_uuid) && appointment.short_uuid.present? && !calendar_options.key?(:t)
      calendar_options[:t] = appointment.short_uuid
    end

    if calendar_options[:host].present?
      Rails.application.routes.url_helpers.admin_calendar_url(calendar_options)
    else
      Rails.application.routes.url_helpers.admin_calendar_path(calendar_options.except(:host, :protocol))
    end
  end

  direct :new_admin_appointment do |options = {}|
    if options[:host].present?
      Rails.application.routes.url_helpers.admin_calendar_url(options)
    else
      Rails.application.routes.url_helpers.admin_calendar_path(options.except(:host, :protocol))
    end
  end

  namespace :super_admin do
    root "businesses#index"
    resource :billing, only: %i[show update], path: "cobros", controller: "billing" do
      patch :update_subscription_price, path: "precio-suscripcion"
      patch "comprobantes/:proof_id/aprobar", to: "billing#approve_payment_proof", as: :approve_payment_proof
      patch "comprobantes/:proof_id/rechazar", to: "billing#reject_payment_proof", as: :reject_payment_proof
    end
    resource :mercado_pago_connection, only: [], path: "mercadopago-suscripciones", controller: "mercado_pago_connections" do
      get :connect, path: "conectar"
      get :callback, path: "callback"
    end
    resource :usage, only: :show, path: "uso", controller: "usage"
    resources :tutorials, path: "tutoriales" do
      collection do
        patch :reorder, path: "ordenar"
      end
    end
    resources :businesses, path: "negocios", only: %i[index new create edit update destroy] do
      collection do
        post :create_demo
      end
      member do
        patch :disable
        patch :enable
        patch :extend_trial
        patch :approve_payment
        patch :reject_payment
        patch :mark_paid
        patch :send_billing_email
        patch :extend_grace
        patch :restrict_billing
        patch :suspend_billing
        patch :reactivate_billing
        patch :cancel_billing
        post :impersonate, to: "impersonations#create"
      end
    end
    resource :impersonation, only: :destroy
  end

  namespace :webhooks do
    post "mercado-pago" => "mercado_pago#create", as: :mercado_pago
    post "mercado-pago-suscripciones" => "platform_mercado_pago#create", as: :platform_mercado_pago
  end

  get "t/:token" => "appointment_actions#show", as: :appointment_action
  post "t/:token/confirmar" => "appointment_actions#confirm", as: :confirm_appointment_action
  post "t/:token/cancelar" => "appointment_actions#cancel", as: :cancel_appointment_action
  get "comprobantes/:token" => "deposit_receipts#show", as: :deposit_receipt
  post "comprobantes/:token" => "deposit_receipts#update"
  get "d/:token" => "deposit_reviews#show", as: :deposit_review
  post "d/:token/confirmar" => "deposit_reviews#confirm", as: :confirm_deposit_review
  post "d/:token/rechazar" => "deposit_reviews#reject", as: :reject_deposit_review
  get "depositos/:token" => "deposit_reviews#show", as: :legacy_deposit_review
  post "depositos/:token/confirmar" => "deposit_reviews#confirm", as: :confirm_legacy_deposit_review
  post "depositos/:token/rechazar" => "deposit_reviews#reject", as: :reject_legacy_deposit_review
  get "invitaciones/empleado/:token" => "employee_invitations#show", as: :employee_invitation
  patch "invitaciones/empleado/:token" => "employee_invitations#update"
  get "w/:token" => "waitlist_confirmations#show", as: :waitlist_confirmation
  post "w/:token/confirmar" => "waitlist_confirmations#confirm", as: :confirm_waitlist_confirmation
  get "l/:slug" => "campaign_links#show", as: :campaign_link

  scope ":slug", as: :customer_portal do
    get "mis-turnos" => "customer_portal/sessions#new", as: :entry
    post "mis-turnos" => "customer_portal/sessions#create"
    get "mis-turnos/acceder/:token" => "customer_portal/sessions#show", as: :access
    get "mis-turnos/panel" => "customer_portal/dashboard#show", as: :dashboard
    patch "mis-turnos/panel" => "customer_portal/dashboard#update", as: :dashboard_update
    delete "mis-turnos/salir" => "customer_portal/sessions#destroy", as: :logout
    get "mis-turnos/:token" => "customer_portal/sessions#profile", as: :profile_access
    get "turno/:token" => "customer_portal/bookings#show", as: :short_booking
    get "mis-turnos/reserva/:token" => "customer_portal/bookings#show", as: :booking
    get "mis-turnos/reserva/:token/reprogramar/disponibilidad" => "customer_portal/bookings#reschedule_availability", as: :booking_reschedule_availability
    post "mis-turnos/reserva/:token/comprobante" => "customer_portal/bookings#upload_receipt", as: :booking_receipt
    post "mis-turnos/reserva/:token/reprogramar" => "customer_portal/bookings#request_reschedule", as: :booking_reschedule
    post "mis-turnos/reserva/:token/cancelar" => "customer_portal/bookings#cancel", as: :booking_cancel
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  get ":slug/calendar.ics" => "public_booking#calendar", as: :public_booking_calendar, defaults: { format: :ics }
  post ":slug/chat" => "chats#create", as: :center_chat
  post ":slug/lista-de-espera" => "waitlist_entries#create", as: :public_waitlist_entries
  get ":slug/servicios" => "public_service_pages#index", as: :public_services
  get ":slug/servicios/:service_slug" => "public_service_pages#show", as: :public_service
  get ":slug/promos" => "public_service_pages#promos", as: :public_promos
  get ":slug" => "public_booking#show", as: :public_business
  get ":slug/reservar" => "public_booking#new", as: :new_public_booking
  post ":slug/reservar" => "public_booking#create", as: :public_bookings
  get ":slug/:category_slug/:service_slug" => "public_booking#new", as: :public_category_service
  get ":slug/:category_slug" => "public_service_pages#category", as: :public_category, constraints: PublicCategoryConstraint.new(custom_domain: false)
  get "*unmatched", to: redirect("/", status: 302), constraints: ->(request) { !request.path.start_with?("/rails/") }
end
