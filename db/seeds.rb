if Rails.env.production? && ENV["ALLOW_DESTRUCTIVE_DEMO_SEED"] != "true"
  abort "Este seed borra datos. Para ejecutarlo en produccion defini ALLOW_DESTRUCTIVE_DEMO_SEED=true."
end

class DemoSeeds
  DEFAULT_PASSWORD = ENV.fetch("DEMO_ADMIN_PASSWORD", "password123")
  SUPER_ADMIN_EMAIL = ENV.fetch("SUPER_ADMIN_EMAIL", "admin@cita.pet.test")
  SUPER_ADMIN_PASSWORD = ENV.fetch("SUPER_ADMIN_PASSWORD", "12345678")

  DEMOS = [
    {
      slug: "patitas-grooming",
      admin_email: "admin@patitas-grooming.cita.pet.test",
      name: "Patitas Cita.pet",
      business_kind: "business",
      industry: "dog_grooming",
      phone: "+5491123456712",
      address: "Av. Cabildo 1840",
      city: "Belgrano, Buenos Aires",
      latitude: -34.5625000,
      longitude: -58.4567000,
      cancellation_notice_hours: 24,
      preferences: {
        chatbot_enabled: true,
        deposits_enabled: true,
        deposit_percentage: 50,
        deposit_alias: "patitas.grooming",
        deposit_account: "0000003100098765432101",
        deposit_holder: "Patitas Cita.pet",
        deposit_tax_id: "30-87654321-4",
        deposit_instructions: "Para reservar, transferí la seña y subí el comprobante. La peluquería canina confirma luego de revisarlo.",
        deposit_payment_link: "https://www.mercadopago.com.ar"
      },
      ai_context: [
        "Patitas Cita.pet usa la suscripción Cita.pet: precio fijo mensual para operar reservas, equipo y pagos.",
        "La cuenta admin administra el negocio, la facturación, los permisos y la configuración sensible.",
        "La peluquería trabaja con bañeras, mesas de grooming, secadores y caniles que no pueden superponerse.",
        "Las groomers tienen permisos operativos distintos para turnos, comprobantes, tutores, mascotas, servicios y recursos.",
        "El tutor puede reservar online para su mascota y la peluquería confirma o revisa señas desde el panel.",
        "Para el baño y corte, confirmar antes el tamaño, tipo de manto, estado de la piel y cualquier cuidado veterinario indicado por el tutor.",
        "Si una agenda está completa, la lista de espera permite llenar huecos por cancelaciones."
      ],
      weekly_hours: {
        1 => [ true, "09:00", "19:00" ],
        2 => [ true, "09:00", "19:00" ],
        3 => [ true, "09:00", "19:00" ],
        4 => [ true, "09:00", "19:00" ],
        5 => [ true, "09:00", "19:00" ],
        6 => [ true, "10:00", "16:00" ],
        0 => [ false, "09:00", "18:00" ]
      },
      branches: [
        { name: "Belgrano", address: "Av. Cabildo 1840", city: "Belgrano, Buenos Aires", phone: "+5491123456712" },
        { name: "Palermo", address: "Gorriti 4860", city: "Palermo, Buenos Aires", phone: "+5491123456713" }
      ],
      employees: [
        {
          name: "Valentina Suárez",
          email: "valentina@patitas-grooming.cita.pet.test",
          phone: "+5491111111301",
          specialty: "Baño y secado",
          branch_name: "Belgrano",
          sort_order: 1,
          permissions: EmployeeMembership::PERMISSIONS.keys,
          schedule: {
            1 => [ true, "09:00", "18:00" ],
            2 => [ true, "09:00", "18:00" ],
            3 => [ true, "09:00", "18:00" ],
            4 => [ true, "09:00", "18:00" ],
            5 => [ true, "09:00", "16:00" ],
            6 => [ true, "10:00", "16:00" ],
            0 => [ false, "09:00", "18:00" ]
          }
        },
        {
          name: "Lucía Fernández",
          email: "lucia@patitas-grooming.cita.pet.test",
          phone: "+5491111111302",
          specialty: "Cortes de raza y styling",
          branch_name: "Belgrano",
          sort_order: 2,
          permissions: %w[can_view_all_bookings can_create_bookings can_edit_bookings can_cancel_bookings can_approve_deposits can_reject_deposits can_view_all_customers can_edit_customers can_edit_internal_notes can_manage_resources],
          schedule: {
            1 => [ true, "10:00", "19:00" ],
            2 => [ true, "10:00", "19:00" ],
            3 => [ false, "10:00", "19:00" ],
            4 => [ true, "10:00", "19:00" ],
            5 => [ true, "10:00", "18:00" ],
            6 => [ false, "10:00", "16:00" ],
            0 => [ false, "09:00", "18:00" ]
          }
        },
        {
          name: "Martina Ríos",
          email: "martina@patitas-grooming.cita.pet.test",
          phone: "+5491111111303",
          specialty: "Higiene y bienestar",
          branch_name: "Palermo",
          sort_order: 3,
          permissions: EmployeeMembership::DEFAULT_PERMISSIONS,
          schedule: {
            1 => [ false, "09:00", "18:00" ],
            2 => [ true, "11:00", "19:00" ],
            3 => [ true, "11:00", "19:00" ],
            4 => [ true, "11:00", "19:00" ],
            5 => [ true, "11:00", "19:00" ],
            6 => [ true, "10:00", "16:00" ],
            0 => [ false, "09:00", "18:00" ]
          }
        },
        {
          name: "Rocío Benítez",
          email: "rocio@patitas-grooming.cita.pet.test",
          phone: "+5491111111304",
          specialty: "Deslanado y mantención",
          branch_name: "Palermo",
          sort_order: 4,
          permissions: %w[can_create_bookings can_edit_bookings can_edit_internal_notes can_manage_services],
          schedule: {
            1 => [ true, "14:00", "19:00" ],
            2 => [ true, "14:00", "19:00" ],
            3 => [ true, "14:00", "19:00" ],
            4 => [ true, "14:00", "19:00" ],
            5 => [ false, "14:00", "19:00" ],
            6 => [ true, "10:00", "14:00" ],
            0 => [ false, "09:00", "18:00" ]
          }
        },
        {
          name: "Julieta Acosta",
          email: "julieta@patitas-grooming.cita.pet.test",
          phone: "+5491111111305",
          specialty: "Puppies y adaptación",
          branch_name: "Palermo",
          sort_order: 5,
          status: "pending",
          permissions: EmployeeMembership::DEFAULT_PERMISSIONS,
          schedule: {
            1 => [ true, "09:00", "14:00" ],
            2 => [ true, "09:00", "14:00" ],
            3 => [ true, "09:00", "14:00" ],
            4 => [ false, "09:00", "14:00" ],
            5 => [ true, "09:00", "14:00" ],
            6 => [ false, "10:00", "16:00" ],
            0 => [ false, "09:00", "18:00" ]
          }
        }
      ],
      resources: [
        "Bañera hidráulica 1",
        "Bañera hidráulica 2",
        "Mesa de grooming 1",
        "Mesa de grooming 2",
        "Secador profesional",
        "Soplador de alto caudal",
        "Área de secado",
        "Canil de espera"
      ],
      services: [
        { name: "Baño y secado", category: "Baño y secado", description: "Baño con productos acordes al tipo de manto, secado completo y cepillado suave.", duration_minutes: 60, price_cents: 24_000_00, resources: [ "Bañera hidráulica 1", "Bañera hidráulica 2", "Secador profesional" ], employees: [ "Valentina Suárez" ], deposit_required: true, deposit_amount_cents: 6_000_00, professional_selection_mode: "hidden", popular: true, tags: %w[baño secado perro manto cepillado] },
        { name: "Baño y corte", category: "Baño y secado", description: "Baño, secado, cepillado y corte adaptado al manto y a la rutina de la mascota.", duration_minutes: 120, price_cents: 42_000_00, resources: [ "Bañera hidráulica 1", "Bañera hidráulica 2", "Mesa de grooming 1", "Mesa de grooming 2", "Secador profesional" ], employees: [ "Valentina Suárez", "Lucía Fernández" ], deposit_required: true, deposit_amount_cents: 12_000_00, popular: true, tags: %w[baño corte grooming perro peluquería] },
        { name: "Corte de raza", category: "Corte y arreglo", description: "Corte técnico respetando el estándar o el estilo acordado con el tutor.", duration_minutes: 120, price_cents: 52_000_00, resources: [ "Mesa de grooming 1", "Mesa de grooming 2", "Secador profesional" ], employees: [ "Lucía Fernández" ], deposit_required: true, deposit_amount_cents: 15_000_00, tags: %w[corte raza grooming manto tijera] },
        { name: "Deslanado intensivo", category: "Corte y arreglo", description: "Remoción de subpelo muerto, cepillado profundo y terminación prolija.", duration_minutes: 90, price_cents: 36_000_00, resources: [ "Mesa de grooming 1", "Mesa de grooming 2", "Soplador de alto caudal" ], employees: [ "Rocío Benítez" ], deposit_required: true, deposit_amount_cents: 10_000_00, tags: %w[deslanado subpelo cepillado muda perro] },
        { name: "Corte higiénico", category: "Higiene y bienestar", description: "Recorte de zonas higiénicas, patas y contorno para mantener comodidad y limpieza.", duration_minutes: 45, price_cents: 19_000_00, resources: [ "Mesa de grooming 1", "Mesa de grooming 2" ], employees: [ "Martina Ríos", "Rocío Benítez" ], tags: %w[corte higiénico higiene patas pelo perro] },
        { name: "Higiene completa", category: "Higiene y bienestar", description: "Limpieza de oídos, corte de uñas, higiene de almohadillas y cepillado.", duration_minutes: 45, price_cents: 21_000_00, resources: [ "Mesa de grooming 1", "Mesa de grooming 2" ], employees: [ "Martina Ríos" ], tags: %w[higiene uñas oídos almohadillas perro] },
        { name: "Baño medicado", category: "Higiene y bienestar", description: "Baño con el producto indicado por el tutor o veterinario y secado cuidadoso.", duration_minutes: 75, price_cents: 31_000_00, resources: [ "Bañera hidráulica 1", "Bañera hidráulica 2", "Secador profesional" ], employees: [ "Martina Ríos" ], deposit_required: true, deposit_amount_cents: 9_000_00, professional_selection_mode: "hidden", use_advanced_availability: true, availability_rules: [ { weekday: 2, start_time: "10:00", end_time: "16:00" }, { weekday: 4, start_time: "10:00", end_time: "16:00" } ], tags: %w[baño medicado piel veterinario perro] },
        { name: "Primera visita puppy", category: "Puppies y especiales", description: "Experiencia gradual para cachorros: baño suave, secado breve y adaptación a la mesa.", duration_minutes: 60, price_cents: 26_000_00, resources: [ "Bañera hidráulica 1", "Mesa de grooming 1", "Secador profesional" ], employees: [ "Valentina Suárez", "Julieta Acosta" ], popular: true, tags: %w[puppy cachorro primera visita adaptación baño] },
        { name: "Spa e hidratación", category: "Puppies y especiales", description: "Baño, mascarilla hidratante, secado y cepillado para mantos que necesitan cuidado extra.", duration_minutes: 90, price_cents: 34_000_00, resources: [ "Bañera hidráulica 1", "Bañera hidráulica 2", "Mesa de grooming 1", "Secador profesional" ], employees: [ "Valentina Suárez", "Rocío Benítez" ], deposit_required: true, deposit_amount_cents: 9_000_00, tags: %w[spa hidratación manto baño grooming] }
      ],
      recommendations: {
        "Baño y secado" => [ "Higiene completa", "Corte higiénico" ],
        "Baño y corte" => [ "Higiene completa", "Spa e hidratación" ],
        "Deslanado intensivo" => [ "Baño y secado" ],
        "Primera visita puppy" => [ "Baño y corte" ]
      },
      dynamic_pricing_rules: [
        { day_of_week: 2, start_time: "14:00", end_time: "17:00", discount_percentage: 12 },
        { day_of_week: 4, start_time: "10:00", end_time: "13:00", discount_percentage: 15 },
        { day_of_week: 6, start_time: "10:00", end_time: "12:00", discount_percentage: 8 }
      ],
      customers: [
        {
          name: "Sofía Morales", phone: "+5491111111201", email: "sofia.morales@example.com",
          notes: [ { title: "Preferencias de Milo", note_type: "general", body: "Milo se siente más tranquilo si Sofía lo acompaña hasta la recepción. Avisar antes de usar el soplador." } ],
          pets: [
            { name: "Milo", breed: "Caniche", sex: "male", birth_date: "2021-05-20", notes: "Manto rizado; cepillar con suavidad las patas." },
            { name: "Pipa", breed: "Mestiza", sex: "female", birth_date: "2020-10-12", notes: "Se queda sólo para baño y secado." }
          ]
        },
        {
          name: "Agustina Vega", phone: "+5491111111202", email: "agustina.vega@example.com",
          notes: [ { title: "Piel sensible", note_type: "clinical", body: "Luna tiene piel sensible. Usar el shampoo que trae Agustina y avisar si hay enrojecimiento." } ],
          pets: [ { name: "Luna", breed: "Golden Retriever", sex: "female", birth_date: "2019-03-08", notes: "Mucha muda estacional; priorizar deslanado." } ]
        },
        {
          name: "Romina Duarte", phone: "+5491111111203", email: "romina.duarte@example.com",
          pets: [ { name: "Simón", breed: "Labrador Retriever", sex: "male", birth_date: "2018-09-15", notes: "Amigable con el baño; secar bien debajo del collar." } ]
        },
        {
          name: "Carla Núñez", phone: "+5491111111204", email: "carla.nunez@example.com",
          notes: [ { title: "Cuidado veterinario", note_type: "technical", body: "Nala está en control dermatológico. Aplicar sólo el producto indicado por Carla." } ],
          pets: [ { name: "Nala", breed: "Mestiza", sex: "female", birth_date: "2020-01-29", notes: "No usar perfume; confirmar el producto medicado al ingreso." } ]
        },
        {
          name: "Belén Acosta", phone: "+5491111111205", email: "belen.acosta@example.com",
          notes: [ { title: "Preferencias", note_type: "general", body: "Mora suele venir por la mañana y responde mejor a una sesión tranquila." } ],
          pets: [ { name: "Mora", breed: "Shih Tzu", sex: "female", birth_date: "2022-07-04", notes: "Mantener el flequillo despejado y hacer corte higiénico." } ]
        },
        {
          name: "Natalia Ríos", phone: "+5491111111206", email: "natalia.rios@example.com",
          pets: [ { name: "Rocky", breed: "Border Collie", sex: "male", birth_date: "2021-02-18", notes: "Energético; coordinar deslanado después de un paseo corto." } ]
        },
        {
          name: "Marina Castro", phone: "+5491111111207", email: "marina.castro@example.com",
          pets: [ { name: "Toby", breed: "Yorkshire Terrier", sex: "male", birth_date: "2019-11-03", notes: "Corte de manto largo; evitar tirar del pelo de las orejas." } ]
        },
        {
          name: "Lucía Fernández", phone: "+5491111111208", email: "lucia.fernandez@example.com",
          pets: [ { name: "Kira", breed: "Labrador Retriever", sex: "female", birth_date: "2017-06-22", notes: "Baño completo y control de uñas." } ]
        }
      ],
      appointments: [
        { key: "milo_bano_historico", service_name: "Baño y secado", pet_name: "Milo", customer_phone: "+5491111111201", date: -20, time: "10:00", status: :confirmed, source: :public_booking, employee_name: "Valentina Suárez", resource_name: "Bañera hidráulica 1", branch_name: "Belgrano", notes: "Patitas histórico: Milo toleró bien el baño y el secado." },
        { key: "luna_deslanado_historico", service_name: "Deslanado intensivo", pet_name: "Luna", customer_phone: "+5491111111202", date: -16, time: "14:00", status: :confirmed, source: :public_booking, employee_name: "Rocío Benítez", resource_name: "Soplador de alto caudal", branch_name: "Belgrano", notes: "Patitas histórico: deslanado de Luna realizado sin inconvenientes." },
        { key: "simon_bano_historico", service_name: "Baño y corte", pet_name: "Simón", customer_phone: "+5491111111203", date: -10, time: "17:00", status: :confirmed, source: :manual, employee_name: "Valentina Suárez", resource_name: "Bañera hidráulica 2", branch_name: "Palermo", notes: "Patitas histórico: baño completo y recorte de Simón." },
        { key: "nala_cancelada", service_name: "Baño medicado", pet_name: "Nala", customer_phone: "+5491111111204", date: -7, time: "12:00", status: :canceled, source: :public_booking, employee_name: "Martina Ríos", resource_name: "Bañera hidráulica 1", branch_name: "Belgrano", notes: "Patitas cancelado: Carla avisó fuera de término.", canceled_late: true },
        { key: "milo_bano_hoy", service_name: "Baño y secado", pet_name: "Milo", customer_phone: "+5491111111201", date: :today, time: "10:00", status: :confirmed, source: :manual, employee_name: "Valentina Suárez", resource_name: "Bañera hidráulica 1", branch_name: "Belgrano", notes: "Patitas hoy: Valentina recibe a Milo por la mañana." },
        { key: "mora_higiene_hoy", service_name: "Higiene completa", pet_name: "Mora", customer_phone: "+5491111111205", date: :today, time: "11:00", status: :confirmed, source: :manual, employee_name: "Martina Ríos", resource_name: "Mesa de grooming 1", branch_name: "Palermo", notes: "Patitas hoy: higiene y corte de uñas de Mora." },
        { key: "toby_corte_hoy", service_name: "Corte de raza", pet_name: "Toby", customer_phone: "+5491111111207", date: :today, time: "10:00", status: :confirmed, source: :manual, employee_name: "Lucía Fernández", resource_name: "Mesa de grooming 2", branch_name: "Palermo", notes: "Patitas hoy: Lucía realiza el corte de manto largo de Toby." },
        { key: "milo_corte_proximo", service_name: "Baño y corte", pet_name: "Milo", customer_phone: "+5491111111201", date: :next_monday, time: "10:00", status: :confirmed, source: :public_booking, employee_name: "Lucía Fernández", resource_name: "Mesa de grooming 1", branch_name: "Belgrano", notes: "Patitas próximo: baño y corte de mantenimiento para Milo." },
        { key: "luna_deslanado_proximo", service_name: "Deslanado intensivo", pet_name: "Luna", customer_phone: "+5491111111202", date: :next_tuesday, time: "14:00", status: :confirmed, source: :public_booking, employee_name: "Rocío Benítez", resource_name: "Soplador de alto caudal", branch_name: "Belgrano", notes: "Patitas próximo: deslanado de Luna." },
        { key: "simon_comprobante", service_name: "Baño y corte", pet_name: "Simón", customer_phone: "+5491111111203", date: :next_wednesday, time: "17:00", status: :pending_deposit_review, source: :public_booking, employee_name: "Valentina Suárez", resource_name: "Bañera hidráulica 2", branch_name: "Palermo", notes: "Patitas comprobante: revisar seña de Simón.", deposit_status: "submitted" },
        { key: "nala_medicado_proximo", service_name: "Baño medicado", pet_name: "Nala", customer_phone: "+5491111111204", date: :next_thursday, time: "12:00", status: :confirmed, source: :manual, employee_name: "Martina Ríos", resource_name: "Bañera hidráulica 1", branch_name: "Belgrano", notes: "Patitas próximo: confirmar shampoo indicado al ingreso." },
        { key: "mora_higiene_pendiente", service_name: "Higiene completa", pet_name: "Mora", customer_phone: "+5491111111205", date: :next_friday, time: "11:00", status: :pending_confirmation, source: :public_booking, employee_name: "Martina Ríos", resource_name: "Mesa de grooming 1", branch_name: "Palermo", notes: "Patitas pendiente: confirmar horario con Belén.", deposit_status: "not_required" },
        { key: "rocky_sena", service_name: "Baño y corte", pet_name: "Rocky", customer_phone: "+5491111111206", date: :next_friday, time: "16:00", status: :pending_deposit, source: :public_booking, employee_name: "Valentina Suárez", resource_name: "Bañera hidráulica 2", branch_name: "Belgrano", notes: "Patitas seña pendiente para Rocky.", deposit_status: "pending" },
        { key: "toby_rechazada", service_name: "Corte de raza", pet_name: "Toby", customer_phone: "+5491111111207", date: :next_thursday, time: "17:00", status: :deposit_rejected, source: :public_booking, employee_name: "Lucía Fernández", resource_name: "Mesa de grooming 2", branch_name: "Palermo", notes: "Patitas seña rechazada: monto incorrecto.", deposit_status: "rejected", deposit_rejection_reason: "El monto transferido no coincide con la seña solicitada." }
      ],
      full_day_blocks: [
        { service_name: "Baño y secado", date: :next_saturday, start_time: "10:00", end_time: "16:00", employee_name: "Valentina Suárez", resource_name: "Bañera hidráulica 1", branch_name: "Belgrano", customer_prefix: "Patitas baño ocupado", pet_prefix: "Perrito baño", notes_prefix: "Patitas baño lleno" },
        { service_name: "Higiene completa", date: :next_saturday, start_time: "10:00", end_time: "16:00", employee_name: "Martina Ríos", resource_name: "Mesa de grooming 1", branch_name: "Palermo", customer_prefix: "Patitas higiene ocupada", pet_prefix: "Perrita higiene", notes_prefix: "Patitas higiene lleno" }
      ],
      resource_blocks: [
        { resource_name: "Secador profesional", date: :today, start_time: "18:00", end_time: "18:45", reason: "maintenance" },
        { resource_name: "Bañera hidráulica 2", date: :tomorrow, start_time: "09:00", end_time: "12:00", reason: "repair" }
      ],
      availability_blocks: [
        { employee_name: "Lucía Fernández", date: :next_tuesday, start_time: "16:00", end_time: "17:00", block_type: "professional_block", reason: "Capacitación interna de grooming" },
        { resource_name: "Soplador de alto caudal", date: :next_wednesday, start_time: "18:00", end_time: "18:45", block_type: "resource_block", reason: "Mantenimiento preventivo" },
        { date: :next_thursday, start_time: "13:30", end_time: "14:30", block_type: "lunch", reason: "Almuerzo del equipo" }
      ],
      holidays: [
        { date: :next_sunday, name: "Feriado de la peluquería", closed: true }
      ],
      waitlist_entries: [
        { service_name: "Baño y corte", client_name: "Natalia y Rocky", client_phone: "+5491111111291", desired_date: :next_saturday },
        { service_name: "Baño y secado", client_name: "Belén y Mora", client_phone: "+5491111111292", desired_date: :next_saturday },
        { service_name: "Higiene completa", client_name: "Marina y Toby", client_phone: "+5491111111293", desired_date: :next_saturday }
      ],
      provider_events: [
        { event_type: "deposit_receipt_submitted", title: "Comprobante pendiente de revisión", body: "Romina subió el comprobante para el baño y corte de Simón.", appointment_key: "simon_comprobante" },
        { event_type: "new_booking", title: "Reserva nueva para coordinar", body: "Belén pidió higiene completa para Mora en Palermo. Falta confirmar el horario.", appointment_key: "mora_higiene_pendiente" },
        { event_type: "waitlist_released_slot", title: "Lista de espera con demanda", body: "Hay tres tutores esperando turnos de sábado para baño e higiene.", metadata: { segment: "patitas_lista_espera" } }
      ],
      conversations: [
        {
          visitor_token: "patitas-chat-1",
          customer_name: "Natalia Ríos",
          customer_phone: "+5491111111206",
          last_intent: "booking",
          status: "open",
          summary_status: "pending",
          messages: [
            [ "user", "Hola, quiero baño y corte para Rocky. Hay turno el viernes?" ],
            [ "assistant", "Hola Natalia. Hay una opción el viernes a las 16:00 con Valentina y la bañera hidráulica 2." ],
            [ "user", "Perfecto, cómo hago con la seña?" ],
            [ "assistant", "Te dejo la solicitud y el link para subir el comprobante. La peluquería confirma cuando lo revisa." ]
          ]
        },
        {
          visitor_token: "patitas-chat-2",
          customer_name: "Agustina Vega",
          customer_phone: "+5491111111202",
          last_intent: "complaint_followup",
          status: "summarized",
          summary_status: "completed",
          summary: "La tutora mencionó demora en el deslanado de Luna y requiere seguimiento manual.",
          messages: [
            [ "user", "La última vez esperé bastante para el deslanado de Luna." ],
            [ "assistant", "Gracias por avisarnos. Voy a dejarlo registrado para que la peluquería pueda revisarlo y contactarte." ]
          ]
        }
      ]
    }
  ].freeze

  DATE_ALIASES = {
    next_monday: 1,
    next_tuesday: 2,
    next_wednesday: 3,
    next_thursday: 4,
    next_friday: 5,
    next_saturday: 6,
    next_sunday: 0
  }.freeze

  def self.call
    new.call
  end

  def call
    reset_database!
    ServiceCatalog::DefaultCatalog.seed!
    seed_super_admin!

    DEMOS.each do |demo|
      admin = seed_admin(demo)
      business = seed_business(demo, admin)
      seed_subscription(business)
      business.update!(simultaneous_capacity: 3, arrival_mode: "fixed", arrival_times: (0..6).to_h { |day| [ day.to_s, %w[09:00 12:00 15:00] ] }, preferences: business.preferences.merge("deposits_enabled" => true, "enabled_payment_methods" => [ "mercado_pago" ]))
      seed_availability(business, demo.fetch(:weekly_hours))
      Grooming::Catalog.install!(business)
    end

    puts "\nDemos listas:"
    DEMOS.each do |demo|
      puts "  Admin: #{demo.fetch(:admin_email)}"
      puts "  Password: #{DEFAULT_PASSWORD}"
      puts "  Panel: http://localhost:3003/admin"
      puts "  Web pública: http://localhost:3003/#{demo.fetch(:slug)}"
      puts ""
    end
  end

  private
    def reset_database!
      connection = ActiveRecord::Base.connection
      tables = connection.tables - %w[ar_internal_metadata schema_migrations]
      return if tables.empty?

      quoted_tables = tables.map { |table| connection.quote_table_name(table) }.join(", ")
      connection.execute("TRUNCATE TABLE #{quoted_tables} RESTART IDENTITY CASCADE")
      puts "Base de datos limpiada."
    end

    def seed_super_admin!
      user = User.create!(
        email_address: SUPER_ADMIN_EMAIL,
        password: SUPER_ADMIN_PASSWORD,
        role: :super_admin
      )
      puts "Super admin listo: #{user.email_address}"
    end

    def seed_demo(demo)
      admin = seed_admin(demo)
      business = seed_business(demo, admin)
      seed_subscription(business)
      seed_availability(business, demo.fetch(:weekly_hours))
      branches = seed_branches(business, demo.fetch(:branches))
      employees = seed_employees(business, demo.fetch(:employees, []), branches)
      resources = seed_resources(business, demo.fetch(:resources))
      services = seed_services(business, demo.fetch(:services), resources, employees)
      seed_recommendations(services, demo.fetch(:recommendations))
      seed_dynamic_pricing(business, demo.fetch(:dynamic_pricing_rules))
      customers = seed_customers(business, admin, demo.fetch(:customers))
      appointments = seed_appointments(business, demo.fetch(:appointments), branches:, employees:, resources:, services:, customers:)
      seed_full_day_blocks(business, demo.fetch(:full_day_blocks, []), branches:, employees:, resources:, services:, customers:)
      seed_resource_blocks(business, demo.fetch(:resource_blocks, []), resources:)
      seed_availability_blocks(business, demo.fetch(:availability_blocks, []), employees:, resources:)
      seed_holidays(business, demo.fetch(:holidays, []))
      seed_waitlist_entries(business, demo.fetch(:waitlist_entries, []), services:)
      seed_provider_events(business, admin, demo.fetch(:provider_events, []), appointments:)
      seed_conversations(business, demo.fetch(:conversations, []))

      puts "Demo creada: #{business.slug} - #{business.name}"
    end

    def seed_admin(demo)
      User.create!(
        email_address: demo.fetch(:admin_email),
        password: DEFAULT_PASSWORD,
        role: :admin
      )
    end

    def seed_business(demo, admin)
      Business.create!(
        owner: admin,
        slug: demo.fetch(:slug),
        name: demo.fetch(:name),
        business_kind: demo.fetch(:business_kind),
        industry: demo.fetch(:industry),
        contact_phone: demo.fetch(:phone),
        phone: demo.fetch(:phone),
        whatsapp_phone: demo.fetch(:phone),
        address: demo.fetch(:address),
        city: demo.fetch(:city),
        latitude: demo.fetch(:latitude),
        longitude: demo.fetch(:longitude),
        cancellation_notice_hours: demo.fetch(:cancellation_notice_hours),
        preferences: demo.fetch(:preferences),
        ai_chat_enabled: true,
        ai_context: demo.fetch(:ai_context).join("\n"),
        onboarding_completed_at: Time.current,
        trial_started_at: Time.current,
        trial_ends_at: 14.days.from_now,
        setup_status: "completed",
        disabled_at: nil
      )
    end

    def seed_subscription(business)
      subscription = business.subscription || business.build_subscription
      subscription.update!(
        external_reference: "demo-#{business.slug}",
        status: "authorized",
        payer_email: business.owner.email_address,
        subscribed_at: Time.current,
        last_payment_at: Time.current,
        expires_at: 1.year.from_now,
        raw_payload: { seed: true, subscription: "fixed_monthly" }
      )
    end

    def seed_availability(business, weekly_hours)
      Business::DAYS.each do |weekday, _name|
        active, start_time, end_time = weekly_hours.fetch(weekday, [ false, "09:00", "18:00" ])
        business.availability_rules.find_or_create_by!(weekday: weekday).update!(
          active: active,
          start_time: start_time,
          end_time: end_time
        )
      end
    end

    def seed_branches(business, branch_definitions)
      business.branches.where.not(name: branch_definitions.map { |branch| branch.fetch(:name) }).destroy_all

      branch_definitions.index_with do |attributes|
        branch = business.branches.find_or_initialize_by(name: attributes.fetch(:name))
        branch.update!(
          active: attributes.fetch(:active, true),
          address: attributes.fetch(:address),
          city: attributes.fetch(:city),
          phone: attributes.fetch(:phone)
        )
        branch
      end.transform_keys { |attributes| attributes.fetch(:name) }
    end

    def seed_employees(business, employee_definitions, branches)
      employee_definitions.index_with do |attributes|
        status = attributes.fetch(:status, "active")
        first_name, last_name = attributes.fetch(:name).to_s.split(/\s+/, 2)
        user = if status == "active"
          User.create!(
            email_address: attributes.fetch(:email),
            password: DEFAULT_PASSWORD,
            role: :employee
          )
        end

        membership = business.employee_memberships.create!(
          user: user,
          name: attributes.fetch(:name),
          first_name: first_name,
          last_name: last_name,
          email_address: attributes.fetch(:email),
          phone: attributes[:phone],
          specialty: attributes[:specialty],
          sort_order: attributes.fetch(:sort_order, 0),
          branch: branches.fetch(attributes.fetch(:branch_name)),
          status: status,
          invitation_sent_at: Time.current,
          invitation_accepted_at: status == "active" ? Time.current : nil,
          invitation_expires_at: status == "pending" ? 7.days.from_now : nil,
          invitation_token_digest: status == "pending" ? BCrypt::Password.create("demo-invitacion-#{business.slug}-#{attributes.fetch(:email)}") : nil,
          invited_by: business.owner,
          permissions: Array(attributes.fetch(:permissions)).index_with { true }
        )
        seed_employee_schedule(membership, attributes.fetch(:schedule, {}))
        membership
      end.transform_keys { |attributes| attributes.fetch(:name) }
    end

    def seed_employee_schedule(membership, schedule)
      return if schedule.blank?

      membership.ensure_availability_rules!
      Business::DAYS.each do |weekday, _name|
        active, start_time, end_time = schedule.fetch(weekday, [ false, "09:00", "18:00" ])
        membership.employee_availability_rules.find_by!(weekday: weekday).update!(
          active: active,
          start_time: start_time,
          end_time: end_time,
          inherits_business_hours: false
        )
      end
    end

    def seed_resources(business, resource_definitions)
      resource_definitions.each_with_object({}) do |definition, memo|
        attributes = resource_attributes_for(definition)
        memo[attributes.fetch(:name)] = business.bookable_resources.create!(attributes)
      end
    end

    def resource_attributes_for(definition)
      attributes = definition.is_a?(Hash) ? definition.symbolize_keys : { name: definition }
      name = attributes.fetch(:name)
      {
        name: name,
        active: attributes.fetch(:active, true),
        resource_type: attributes.fetch(:resource_type, resource_type_for(name)),
        quantity: attributes.fetch(:quantity, resource_quantity_for(name)),
        status: attributes.fetch(:status, "active"),
        notes: attributes.fetch(:notes, resource_notes_for(name))
      }
    end

    def resource_type_for(name)
      normalized = I18n.transliterate(name.to_s).downcase
      return "machine" if normalized.match?(/secador|soplador|equipo/)
      return "cabin" if normalized.match?(/banera|area de secado|canil/)
      return "table" if normalized.include?("mesa")

      "space"
    end

    def resource_quantity_for(name)
      1
    end

    def resource_notes_for(name)
      case resource_type_for(name)
      when "machine" then "Equipo compartido: si está ocupado, los servicios que lo requieren no aparecen disponibles."
      when "cabin" then "Espacio de grooming compartido para baño, secado o espera de mascotas."
      when "table" then "Mesa compartida para corte, higiene y cepillado."
      else "Recurso compartido de la peluquería canina."
      end
    end

    def seed_services(business, service_definitions, resources, employees)
      service_definitions.each_with_index.to_h do |attributes, index|
        service = business.services.create!(
          name: attributes.fetch(:name),
          category: attributes.fetch(:category),
          description: attributes.fetch(:description),
          duration_minutes: attributes.fetch(:duration_minutes),
          price_cents: attributes.fetch(:price_cents),
          deposit_required: attributes.fetch(:deposit_required, false),
          deposit_amount_cents: attributes.fetch(:deposit_amount_cents, 0),
          deposit_percentage: attributes.fetch(:deposit_percentage, 0),
          deposit_payment_deadline_minutes: attributes.fetch(:deposit_payment_deadline_minutes, 30),
          external_payment_link: attributes[:external_payment_link],
          visibility_mode: attributes.fetch(:visibility_mode, "public"),
          professional_selection_mode: attributes.fetch(:professional_selection_mode, "optional"),
          use_advanced_availability: attributes.fetch(:use_advanced_availability, false),
          sort_order: attributes.fetch(:sort_order, index),
          popular: attributes.fetch(:popular, false),
          tags_text: Array(attributes[:tags]).join(", "),
          active: true
        )
        service.bookable_resources = Array(attributes.fetch(:resources, [])).map { |name| resources.fetch(name) }
        service.employee_memberships = Array(attributes.fetch(:employees, [])).map { |name| employees.fetch(name) }
        Array(attributes[:availability_rules]).each do |rule|
          service.service_availability_rules.create!(
            weekday: rule.fetch(:weekday),
            start_time: rule.fetch(:start_time),
            end_time: rule.fetch(:end_time),
            active: rule.fetch(:active, true)
          )
        end
        [ attributes.fetch(:name), service ]
      end
    end

    def seed_recommendations(services, recommendations)
      recommendations.each do |service_name, recommended_names|
        services.fetch(service_name).recommended_services = recommended_names.map { |name| services.fetch(name) }
      end
    end

    def seed_dynamic_pricing(business, rules)
      rules.each do |attributes|
        business.dynamic_pricing_rules.create!(
          day_of_week: attributes.fetch(:day_of_week),
          start_time: attributes.fetch(:start_time),
          end_time: attributes.fetch(:end_time),
          discount_percentage: attributes.fetch(:discount_percentage),
          active: true
        )
      end
    end

    def seed_customers(business, admin, customer_definitions)
      customer_definitions.index_with do |attributes|
        profile = business.customer_profiles.create!(
          name: attributes.fetch(:name),
          phone: attributes.fetch(:phone),
          email: attributes.fetch(:email),
          blocked_at: attributes[:blocked_reason].present? ? Time.current : nil,
          blocked_reason: attributes[:blocked_reason]
        )

        Array(attributes[:pets]).each do |pet_attributes|
          profile.pets.create!(business: business, **pet_attributes.symbolize_keys)
        end

        Array(attributes[:notes]).each do |note|
          profile.client_notes.create!(
            business: business,
            user: admin,
            title: note.fetch(:title),
            note_type: note.fetch(:note_type),
            body: note.fetch(:body)
          )
        end

        profile
      end.transform_keys { |attributes| PhoneNumber.normalize(attributes.fetch(:phone)) }
    end

    def seed_appointments(business, appointment_definitions, branches:, employees:, resources:, services:, customers:)
      appointment_definitions.index_with do |attributes|
        create_appointment(business, attributes, branches:, employees:, resources:, services:, customers:)
      end.transform_keys { |attributes| attributes.fetch(:key) }
    end

    def seed_full_day_blocks(business, block_definitions, branches:, employees:, resources:, services:, customers:)
      block_definitions.each_with_index do |block, block_index|
        service = services.fetch(block.fetch(:service_name))
        date = date_for(block.fetch(:date))
        current = time_on(date, block.fetch(:start_time))
        finish = time_on(date, block.fetch(:end_time))
        sequence = 1

        while current + service.duration_minutes.minutes <= finish
          phone = "+5491198#{business.id.to_s.rjust(4, "0")}#{(block_index + 1).to_s.rjust(2, "0")}#{sequence.to_s.rjust(2, "0")}"
          customer = business.customer_profiles.create!(
            name: "#{block.fetch(:customer_prefix)} #{sequence}",
            phone: phone,
            email: "ocupado#{sequence}@#{business.slug}.example.com"
          )
          pet = customer.pets.create!(
            business: business,
            name: "#{block.fetch(:pet_prefix, "Mascota")} #{sequence}",
            breed: "Mestiza",
            sex: sequence.odd? ? "female" : "male",
            notes: "Mascota demo para representar un turno ocupado."
          )
          customers[customer.normalized_phone] = customer

          create_appointment(
            business,
            {
              key: "#{block.fetch(:notes_prefix)} #{sequence}",
              service_name: block.fetch(:service_name),
              pet_name: pet.name,
              customer_phone: phone,
              date: date,
              time: current.strftime("%H:%M"),
              status: :confirmed,
              source: :manual,
              employee_name: block[:employee_name],
              resource_name: block[:resource_name],
              branch_name: block[:branch_name] || business.branches.first.name,
              notes: "#{block.fetch(:notes_prefix)}: #{current.strftime("%H:%M")}",
              deposit_status: "not_required"
            },
            branches: branches,
            employees: employees,
            resources: resources,
            services: services,
            customers: customers
          )

          current += service.duration_minutes.minutes
          sequence += 1
        end
      end
    end

    def seed_resource_blocks(business, block_definitions, resources:)
      block_definitions.each do |attributes|
        resource = resources.fetch(attributes.fetch(:resource_name))
        date = date_for(attributes.fetch(:date))
        resource.resource_blocks.create!(
          business: business,
          starts_at: time_on(date, attributes.fetch(:start_time)),
          ends_at: time_on(date, attributes.fetch(:end_time)),
          reason: attributes.fetch(:reason, "maintenance")
        )
      end
    end

    def seed_availability_blocks(business, block_definitions, employees:, resources:)
      block_definitions.each do |attributes|
        date = date_for(attributes.fetch(:date))
        business.availability_blocks.create!(
          employee_membership: attributes[:employee_name].present? ? employees.fetch(attributes.fetch(:employee_name)) : nil,
          bookable_resource: attributes[:resource_name].present? ? resources.fetch(attributes.fetch(:resource_name)) : nil,
          starts_at: time_on(date, attributes.fetch(:start_time)),
          ends_at: time_on(date, attributes.fetch(:end_time)),
          block_type: attributes.fetch(:block_type, "center_block"),
          reason: attributes[:reason]
        )
      end
    end

    def seed_holidays(business, holiday_definitions)
      holiday_definitions.each do |attributes|
        business.holidays.create!(
          date: date_for(attributes.fetch(:date)),
          name: attributes.fetch(:name),
          closed: attributes.fetch(:closed, true)
        )
      end
    end

    def create_appointment(business, attributes, branches:, employees:, resources:, services:, customers:)
      service = services.fetch(attributes.fetch(:service_name))
      customer = customers.fetch(PhoneNumber.normalize(attributes.fetch(:customer_phone)))
      pet = customer.pets.find_by!(name: attributes.fetch(:pet_name))
      starts_at = time_on(date_for(attributes.fetch(:date)), attributes.fetch(:time))
      branch = branches.fetch(attributes.fetch(:branch_name, branches.keys.first))
      employee = attributes[:employee_name].present? ? employees.fetch(attributes.fetch(:employee_name)) : nil
      resource = attributes[:resource_name].present? ? resources.fetch(attributes.fetch(:resource_name)) : service.bookable_resources.first
      addon_services = Array(attributes[:addon_service_names]).map { |name| services.fetch(name) }
      base_price_cents = service.price_cents_for_time(starts_at, business)
      addon_price_cents = addon_services.sum(&:price_cents)
      deposit_status = attributes.fetch(:deposit_status, default_deposit_status(attributes.fetch(:status), business))
      deposit_amount_cents = deposit_status == "not_required" ? 0 : service.deposit_amount_cents_for(base_price_cents + addon_price_cents)

      appointment = business.appointments.create!(
        service: service,
        customer_profile: customer,
        pet: pet,
        branch: branch,
        employee_membership: employee,
        bookable_resource: resource,
        customer_name: customer.name,
        customer_phone: customer.phone,
        customer_email: customer.email,
        starts_at: starts_at,
        ends_at: starts_at + service.duration_minutes.minutes,
        status: attributes.fetch(:status),
        source: attributes.fetch(:source),
        notes: attributes.fetch(:notes),
        base_price_cents: service.price_cents,
        final_price_cents: base_price_cents + addon_price_cents,
        discount_percentage: service.dynamic_discount_for_time(starts_at, business),
        deposit_status: deposit_status,
        deposit_amount_cents: deposit_amount_cents,
        deposit_submitted_at: deposit_status == "submitted" ? 1.hour.ago : nil,
        deposit_reviewed_at: %w[approved rejected].include?(deposit_status) ? Time.current : nil,
        deposit_rejection_reason: attributes[:deposit_rejection_reason]
      )

      appointment.update_columns(
        confirmed_at: appointment.confirmed? ? Time.current : nil,
        canceled_at: appointment.canceled? ? Time.current : nil,
        canceled_by: appointment.canceled? ? "seed" : nil,
        cancellation_reason: appointment.canceled? ? "Turno demo cancelado" : nil,
        canceled_late: attributes.fetch(:canceled_late, false)
      )

      addon_services.each do |addon_service|
        appointment.appointment_addons.create!(service: addon_service, price_cents: addon_service.price_cents)
      end

      appointment
    end

    def seed_waitlist_entries(business, entry_definitions, services:)
      entry_definitions.each do |attributes|
        business.waitlist_entries.create!(
          service: services.fetch(attributes.fetch(:service_name)),
          client_name: attributes.fetch(:client_name),
          client_phone: attributes.fetch(:client_phone),
          desired_date: date_for(attributes.fetch(:desired_date)),
          status: attributes.fetch(:status, "waiting")
        )
      end
    end

    def default_deposit_status(status, business)
      return "not_required" unless business.deposits_enabled?

      case status.to_s
      when "confirmed"
        "approved"
      when "canceled"
        "not_required"
      else
        "pending"
      end
    end

    def seed_provider_events(business, admin, event_definitions, appointments:)
      event_definitions.each do |attributes|
        appointment = appointments[attributes[:appointment_key]]
        metadata = attributes.fetch(:metadata, {})
        metadata = metadata.merge(
          appointment_id: appointment.id,
          whatsapp_url: appointment.manual_whatsapp_url
        ) if appointment.present?

        business.provider_events.create!(
          user: admin,
          event_type: attributes.fetch(:event_type),
          title: attributes.fetch(:title),
          body: attributes.fetch(:body),
          metadata: metadata
        )
      end
    end

    def seed_conversations(business, conversation_definitions)
      conversation_definitions.each do |attributes|
        conversation = business.ai_chat_conversations.create!(
          visitor_token: attributes.fetch(:visitor_token),
          customer_name: attributes.fetch(:customer_name),
          customer_phone: attributes.fetch(:customer_phone),
          last_intent: attributes.fetch(:last_intent),
          status: attributes.fetch(:status),
          summary_status: attributes.fetch(:summary_status),
          summary: attributes[:summary],
          summarized_at: attributes[:summary].present? ? 30.minutes.ago : nil,
          metadata: { seed: true }
        )

        attributes.fetch(:messages).each_with_index do |(role, content), index|
          conversation.ai_chat_messages.create!(
            role: role,
            content: content,
            metadata: { seed_index: index + 1 }
          )
        end
      end
    end

    def date_for(value)
      case value
      when Date
        value
      when Time, ActiveSupport::TimeWithZone
        value.to_date
      when Integer
        Time.zone.today + value.days
      when Symbol
        return Time.zone.today if value == :today
        return Time.zone.tomorrow if value == :tomorrow

        next_weekday(DATE_ALIASES.fetch(value), from: Time.zone.tomorrow)
      else
        Date.parse(value.to_s)
      end
    end

    def next_weekday(weekday, from:)
      date = from.to_date
      date += 1.day until date.wday == weekday
      date
    end

    def time_on(date, time)
      hour, minute = time.to_s.split(":").map(&:to_i)
      Time.zone.local(date.year, date.month, date.day, hour, minute)
    end
end

DemoSeeds.call
