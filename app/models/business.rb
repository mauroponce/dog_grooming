class Business < ApplicationRecord
  include PurgesReplacedAttachedBlobs

  SUBSCRIPTION_DETAILS = {
    name: "Suscripción Cita.pet",
    description: "Reservas online para peluquerías caninas, con señas, comprobantes, agenda de mascotas y WhatsApp prearmado.",
    monthly_amount_cents: 3_500_000,
    trial_days: 14,
    setup_included: true,
    contract_required: false,
    features: [
      "Todos los servicios",
      "Reservas ilimitadas",
      "Clientes ilimitados",
      "Comprobantes y Mercado Pago",
      "Recordatorios",
      "Asistente con IA",
      "Configuración inicial",
      "Usuarios administrativos"
    ]
  }.freeze
  TRIAL_GRACE_DAYS = 3
  BOOLEAN = ActiveModel::Type::Boolean.new
  AI_CHAT_PUBLICLY_ENABLED = false
  DEPOSIT_PERCENTAGE_OPTIONS = (10..100).step(10).to_a.freeze
  PUBLIC_FONT_STYLES = %w[system editorial rounded].freeze
  PUBLIC_SITE_MODES = {
    "booking_link" => "Link de reserva",
    "full_website" => "Web completa"
  }.freeze
  PUBLIC_SITE_MODE_DEFAULT = "booking_link"
  CUSTOM_DOMAIN_FORMAT = /\A(?=.{1,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/i
  PLATFORM_HOSTS = %w[cita.pet www.cita.pet custom.cita.pet].freeze
  PUBLIC_BOOKING_ASSIGNMENT_STRATEGIES = %w[first_available balanced_rotation least_daily_load habitual_professional].freeze
  PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_DEFAULT = "first_available"
  PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_LABELS = {
    "first_available" => "Primer profesional disponible",
    "balanced_rotation" => "Reparto equilibrado",
    "least_daily_load" => "Profesional con menor carga del día",
    "habitual_professional" => "Priorizar profesional habitual del cliente"
  }.freeze
  PREFERENCE_DEFAULTS = {
    "chatbot_enabled" => true,
    "deposits_enabled" => false,
    "deposit_percentage" => 50,
    "enabled_payment_methods" => [ "manual_transfer" ],
    "public_booking_allow_professional_selection" => false,
    "public_booking_show_team_members" => false,
    "public_booking_assignment_strategy" => PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_DEFAULT,
    "deposit_alias" => "",
    "deposit_account" => "",
    "deposit_holder" => "",
    "deposit_tax_id" => "",
    "deposit_instructions" => "",
    "deposit_payment_link" => "",
    "setup_warnings" => []
  }.freeze
  PAYMENT_METHODS = %w[manual_transfer mercado_pago].freeze

  BUSINESS_KINDS = {
    "business" => "Cuenta Cita.pet"
  }.freeze

  SETUP_STATUSES = %w[not_started in_progress completed].freeze
  RESERVED_SLUGS = Slugs::GenerateUnique::RESERVED_WORDS
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/jpg image/webp].freeze
  LOGO_MAX_SIZE = 5.megabytes
  PUBLIC_CUSTOM_HTML_MAX_LENGTH = 50_000

  AESTHETICS_SERVICE_TEMPLATES = [
    { name: "Manicuria semipermanente", category: "Uñas", duration_minutes: 60, price: 22_000, description: "Preparación de cutícula, limado y esmaltado semipermanente." },
    { name: "Limpieza facial profunda", category: "Facial", duration_minutes: 90, price: 40_000, description: "Higiene facial con extracciones, alta frecuencia e hidratación según tipo de piel." },
    { name: "Depilación láser axilas", category: "Depilación", duration_minutes: 30, price: 18_000, description: "Sesión láser por zona con indicaciones previas y posteriores." },
    { name: "Kapping gel", category: "Uñas", duration_minutes: 90, price: 34_000, description: "Refuerzo de uña natural con gel y esmaltado." },
    { name: "Perfilado y laminado de cejas", category: "Cejas y pestañas", duration_minutes: 45, price: 24_000, description: "Diseño, perfilado y laminado para ordenar y destacar la mirada." },
    { name: "Drenaje linfático manual", category: "Corporal", duration_minutes: 60, price: 36_000, description: "Masaje suave orientado a retención de líquidos, bienestar y recuperación corporal." },

    { name: "Manicuria tradicional", category: "Uñas", duration_minutes: 45, price: 16_000, description: "Limpieza de cutículas, limado y esmaltado clásico." },
    { name: "Manicuria combinada", category: "Uñas", duration_minutes: 75, price: 25_000, description: "Técnica combinada para cutícula prolija y esmaltado de alta duración." },
    { name: "Pedicuría estética", category: "Uñas", duration_minutes: 60, price: 24_000, description: "Cuidado estético de pies, limado, cutículas e hidratación." },
    { name: "Pedicuría spa", category: "Uñas", duration_minutes: 75, price: 30_000, description: "Pedicuría estética con exfoliación, hidratación y masaje breve." },
    { name: "Uñas esculpidas en gel", category: "Uñas", duration_minutes: 120, price: 48_000, description: "Extensión y construcción de uñas en gel con terminación personalizada." },
    { name: "Uñas acrílicas", category: "Uñas", duration_minutes: 120, price: 48_000, description: "Esculpido acrílico para largo y forma personalizados." },
    { name: "Polygel", category: "Uñas", duration_minutes: 120, price: 50_000, description: "Extensión o refuerzo con polygel para estructura resistente." },
    { name: "Soft gel", category: "Uñas", duration_minutes: 90, price: 42_000, description: "Extensión con tips soft gel y esmaltado." },
    { name: "Nail art simple", category: "Uñas", duration_minutes: 30, price: 8_000, description: "Diseño simple, detalles o decoración por uña." },
    { name: "Retiro de esmaltado o gel", category: "Uñas", duration_minutes: 30, price: 10_000, description: "Retiro cuidado de producto anterior y preparación de la uña." },
    { name: "Tratamiento de parafina manos", category: "Uñas", duration_minutes: 30, price: 12_000, description: "Hidratación intensiva para manos secas con baño de parafina." },

    { name: "Diseño y perfilado de cejas", category: "Cejas y pestañas", duration_minutes: 30, price: 15_000, description: "Diseño de cejas según morfología del rostro." },
    { name: "Laminado de cejas", category: "Cejas y pestañas", duration_minutes: 45, price: 22_000, description: "Peinado y fijación semipermanente para ordenar cejas rebeldes." },
    { name: "Tinte de cejas", category: "Cejas y pestañas", duration_minutes: 30, price: 14_000, description: "Coloración de cejas para intensificar forma y definición." },
    { name: "Lifting de pestañas", category: "Cejas y pestañas", duration_minutes: 60, price: 26_000, description: "Elevación de pestañas naturales desde la raíz con efecto abierto." },
    { name: "Lifting de pestañas con tinte", category: "Cejas y pestañas", duration_minutes: 75, price: 30_000, description: "Lifting de pestañas complementado con tinte para mayor definición." },
    { name: "Extensiones de pestañas clásicas", category: "Cejas y pestañas", duration_minutes: 120, price: 48_000, description: "Aplicación pelo por pelo con efecto natural." },
    { name: "Extensiones de pestañas volumen ruso", category: "Cejas y pestañas", duration_minutes: 120, price: 58_000, description: "Aplicación de volumen para un resultado más intenso." },

    { name: "Higiene facial express", category: "Facial", duration_minutes: 45, price: 26_000, description: "Limpieza facial breve con exfoliación e hidratación." },
    { name: "Hydrafacial", category: "Facial", duration_minutes: 60, price: 55_000, description: "Limpieza, exfoliación e infusión de sueros mediante succión profunda." },
    { name: "Peeling químico suave", category: "Facial", duration_minutes: 45, price: 36_000, description: "Aplicación de ácidos superficiales para renovar textura y luminosidad." },
    { name: "Peeling químico medio", category: "Facial", duration_minutes: 60, price: 48_000, description: "Renovación controlada para manchas, textura y secuelas leves de acné." },
    { name: "Microdermoabrasión punta de diamante", category: "Facial", duration_minutes: 45, price: 34_000, description: "Exfoliación mecánica para pulir la piel y remover células muertas." },
    { name: "Dermaplaning", category: "Facial", duration_minutes: 45, price: 32_000, description: "Exfoliación superficial con retiro de vello fino para mejorar textura y luminosidad." },
    { name: "Radiofrecuencia facial", category: "Facial", duration_minutes: 60, price: 42_000, description: "Estimulación térmica para acompañar tratamientos de firmeza facial." },
    { name: "Microneedling Dermapen", category: "Facial", duration_minutes: 60, price: 55_000, description: "Microperforaciones controladas para estimular renovación y absorción de activos." },
    { name: "HIFU facial", category: "Aparatología", duration_minutes: 60, price: 95_000, description: "Ultrasonido focalizado para trabajar firmeza facial sin cirugía." },
    { name: "Fotorejuvenecimiento IPL", category: "Aparatología", duration_minutes: 45, price: 48_000, description: "Luz pulsada para mejorar apariencia de manchas, textura y luminosidad." },
    { name: "Terapia LED facial", category: "Facial", duration_minutes: 30, price: 22_000, description: "Sesión con luz LED como complemento de protocolos faciales." },
    { name: "Masaje facial Kobido", category: "Facial", duration_minutes: 60, price: 38_000, description: "Masaje facial japonés de efecto tensor y drenante." },
    { name: "Hidratación facial intensiva", category: "Facial", duration_minutes: 60, price: 34_000, description: "Máscara y activos hidratantes para piel deshidratada o apagada." },

    { name: "Cavitación", category: "Aparatología", duration_minutes: 45, price: 38_000, description: "Ultrasonido de baja frecuencia para acompañar protocolos reductores." },
    { name: "Lipoláser", category: "Aparatología", duration_minutes: 45, price: 38_000, description: "Tratamiento corporal localizado con lipoláser y protocolo complementario." },
    { name: "Criolipólisis abdomen", category: "Aparatología", duration_minutes: 60, price: 54_000, description: "Aplicación de frío controlado para tratamiento localizado de adiposidad." },
    { name: "Criolipólisis flancos", category: "Aparatología", duration_minutes: 60, price: 54_000, description: "Sesión de criolipólisis enfocada en laterales o zona localizada." },
    { name: "Radiofrecuencia corporal", category: "Aparatología", duration_minutes: 45, price: 38_000, description: "Tratamiento térmico para acompañar protocolos de firmeza corporal." },
    { name: "Presoterapia", category: "Corporal", duration_minutes: 45, price: 28_000, description: "Compresión neumática para drenaje, piernas cansadas y retención de líquidos." },
    { name: "Ondas de choque", category: "Aparatología", duration_minutes: 45, price: 42_000, description: "Impulsos acústicos para protocolos de celulitis y calidad de piel." },
    { name: "Electromusculación", category: "Aparatología", duration_minutes: 30, price: 45_000, description: "Contracciones electromagnéticas para tonificación muscular." },
    { name: "Maderoterapia", category: "Corporal", duration_minutes: 60, price: 36_000, description: "Masaje corporal con utensilios de madera para moldear y relajar." },
    { name: "Masaje relajante", category: "Masajes", duration_minutes: 60, price: 34_000, description: "Masaje corporal orientado a relajación general." },
    { name: "Masaje descontracturante", category: "Masajes", duration_minutes: 60, price: 38_000, description: "Masaje de presión media o profunda para zonas tensionadas." },
    { name: "Masaje con piedras calientes", category: "Masajes", duration_minutes: 75, price: 44_000, description: "Masaje relajante con calor localizado mediante piedras calientes." },
    { name: "Exfoliación corporal", category: "Spa", duration_minutes: 45, price: 30_000, description: "Exfoliación corporal para renovar y suavizar la piel." },
    { name: "Envoltura corporal", category: "Spa", duration_minutes: 60, price: 38_000, description: "Tratamiento corporal con envoltura nutritiva o descongestiva." },
    { name: "Tratamiento postoperatorio", category: "Postoperatorio", duration_minutes: 60, price: 42_000, description: "Sesión de acompañamiento postoperatorio con técnicas manuales o aparatología según indicación." },

    { name: "Depilación láser pierna completa", category: "Depilación", duration_minutes: 60, price: 44_000, description: "Sesión láser de pierna completa con preparación previa indicada." },
    { name: "Depilación láser cavado", category: "Depilación", duration_minutes: 30, price: 22_000, description: "Sesión láser de cavado con protocolo de cuidado previo y posterior." },
    { name: "Depilación láser rostro", category: "Depilación", duration_minutes: 30, price: 18_000, description: "Sesión láser facial por zona según evaluación." },
    { name: "Depilación láser cuerpo completo", category: "Depilación", duration_minutes: 120, price: 95_000, description: "Sesión integral de depilación láser en múltiples zonas." },
    { name: "Luz pulsada IPL", category: "Depilación", duration_minutes: 45, price: 34_000, description: "Sesión con luz pulsada para depilación o fototratamiento según protocolo." },
    { name: "Depilación con cera", category: "Depilación", duration_minutes: 45, price: 22_000, description: "Depilación tradicional con cera por zonas." },
    { name: "Depilación con hilo rostro", category: "Depilación", duration_minutes: 30, price: 16_000, description: "Depilación facial con hilo, ideal para cejas, bozo o rostro." },

    { name: "Toxina botulínica", category: "Medicina estética", duration_minutes: 30, price: 0, description: "Aplicación médica para suavizar arrugas dinámicas. Requiere profesional habilitado." },
    { name: "Ácido hialurónico labios", category: "Medicina estética", duration_minutes: 45, price: 0, description: "Relleno dérmico para labios realizado por profesional médico habilitado." },
    { name: "Armonización facial", category: "Medicina estética", duration_minutes: 60, price: 0, description: "Evaluación y procedimiento médico de armonización facial según indicación profesional." },
    { name: "Relleno de ojeras", category: "Medicina estética", duration_minutes: 45, price: 0, description: "Tratamiento médico con relleno dérmico en zona de ojeras." },
    { name: "Bioestimuladores de colágeno", category: "Medicina estética", duration_minutes: 60, price: 0, description: "Aplicación médica orientada a estimular firmeza y calidad de piel." },
    { name: "Mesoterapia facial", category: "Medicina estética", duration_minutes: 45, price: 0, description: "Microinyecciones de activos faciales realizadas por profesional habilitado." },
    { name: "Mesoterapia corporal", category: "Medicina estética", duration_minutes: 45, price: 0, description: "Microinyecciones corporales según evaluación médica." },
    { name: "Carboxiterapia", category: "Medicina estética", duration_minutes: 45, price: 0, description: "Aplicación subcutánea de CO2 realizada por profesional habilitado." },
    { name: "Plasma rico en plaquetas PRP facial", category: "Medicina estética", duration_minutes: 60, price: 0, description: "Tratamiento regenerativo con factores de crecimiento realizado por profesional habilitado." },
    { name: "PRP capilar", category: "Capilar", duration_minutes: 60, price: 0, description: "Tratamiento capilar con plasma rico en plaquetas realizado por profesional habilitado." },
    { name: "Exosomas", category: "Medicina estética", duration_minutes: 60, price: 0, description: "Tratamiento regenerativo avanzado según evaluación profesional." },
    { name: "Skinbooster", category: "Medicina estética", duration_minutes: 45, price: 0, description: "Aplicación médica de hidratación profunda con inyectables específicos." },

    { name: "Bronceado sin sol", category: "Bronceado", duration_minutes: 30, price: 24_000, description: "Aplicación de bronceado sin exposición solar." },
    { name: "Evaluación estética inicial", category: "General", duration_minutes: 30, price: 0, description: "Primera evaluación para recomendar protocolos y armar plan de tratamiento." }
  ].freeze

  DOG_GROOMING_SERVICE_TEMPLATES = [
    { name: "Baño y secado", category: "Baño y secado", duration_minutes: 60, price: 24_000, description: "Baño, secado completo y cepillado suave según el tipo de manto." },
    { name: "Baño y corte", category: "Baño y secado", duration_minutes: 120, price: 42_000, description: "Baño, secado, cepillado y corte adaptado a la mascota." },
    { name: "Corte higiénico", category: "Corte y arreglo", duration_minutes: 45, price: 19_000, description: "Recorte de zonas higiénicas, patas y contorno para mantener comodidad y limpieza." },
    { name: "Deslanado intensivo", category: "Mantos especiales", duration_minutes: 90, price: 36_000, description: "Remoción de subpelo muerto, cepillado profundo y terminación prolija." },
    { name: "Higiene completa", category: "Higiene y bienestar", duration_minutes: 45, price: 21_000, description: "Limpieza de oídos, corte de uñas, higiene de almohadillas y cepillado." },
    { name: "Primera visita puppy", category: "Cachorros y adaptación", duration_minutes: 60, price: 26_000, description: "Experiencia gradual para cachorros, con baño suave y adaptación a la mesa." }
  ].freeze

  INDUSTRIES = {
    "dog_grooming" => {
      label: "Peluquería canina",
      category: "Peluquería canina",
      tone: "Cálido, claro y cuidadoso con la mascota. Puede usar un tono cercano, sin sustituir indicaciones veterinarias.",
      guidance: "Priorizá especie, tamaño, tipo de manto, sensibilidad de piel, cuidados veterinarios y tiempo estimado. Confirmá que el turno corresponde a una mascota y a su responsable.",
      service_templates: DOG_GROOMING_SERVICE_TEMPLATES
    },
    "aesthetics" => {
      label: "Estética y belleza",
      category: "Estética",
      tone: "Cercano, cálido y comercial. Puede usar emojis con moderación si el negocio comunica de forma informal.",
      guidance: "Prioriza explicar preparación previa, duración, cuidados posteriores, señas y disponibilidad. Evita prometer resultados médicos.",
      service_templates: AESTHETICS_SERVICE_TEMPLATES
    },
    "barber" => {
      label: "Barbería",
      category: "Belleza",
      tone: "Directo, canchero y práctico. Prioriza disponibilidad rápida, duración, preferencias de corte y puntualidad.",
      guidance: "Aclara duración, tolerancia de llegada tarde, servicios combinados de corte y barba, y recomendaciones simples de mantenimiento.",
      service_templates: [
        { name: "Corte clásico", category: "Cabello", duration_minutes: 30, price: 12_000, description: "Corte a tijera o máquina con terminación prolija." },
        { name: "Corte + barba", category: "Combo", duration_minutes: 60, price: 20_000, description: "Corte completo con perfilado de barba y terminación." },
        { name: "Perfilado de barba", category: "Barba", duration_minutes: 30, price: 9_000, description: "Definición de contornos, rebaje y producto final." },
        { name: "Afeitado tradicional", category: "Barba", duration_minutes: 45, price: 14_000, description: "Afeitado con toalla caliente y navaja." }
      ]
    },
    "nails" => {
      label: "Uñas",
      category: "Belleza",
      tone: "Cercano, detallista y visual. Ayuda a elegir técnica, duración, mantenimiento y cuidados posteriores.",
      guidance: "Explica diferencias entre semi, kapping, soft gel y esculpidas. Recomienda avisar si hay retiro o nail art para reservar el tiempo correcto.",
      service_templates: [
        { name: "Manicuria semipermanente", category: "Uñas", duration_minutes: 60, price: 18_000, description: "Preparación de cutícula y esmaltado semipermanente." },
        { name: "Kapping en gel", category: "Uñas", duration_minutes: 90, price: 26_000, description: "Refuerzo de una natural con gel." },
        { name: "Soft gel", category: "Uñas", duration_minutes: 90, price: 32_000, description: "Extensión con tips soft gel y esmaltado." },
        { name: "Nail art", category: "Diseño", duration_minutes: 30, price: 8_000, description: "Diseño simple o detalle por uña." }
      ]
    },
    "psychology" => {
      label: "Psicología",
      category: "Salud",
      tone: "Serio, empático, sobrio y confidencial. No usa emojis salvo que el contexto del profesional lo indique.",
      guidance: "No diagnostica, no reemplaza atención profesional y sugiere contacto directo ante urgencias o crisis. Mantiene privacidad y claridad.",
      service_templates: [
        { name: "Sesión de terapia individual", category: "Terapia", duration_minutes: 45, price: 0, description: "Espacio de atención psicológica individual." },
        { name: "Primera entrevista", category: "Terapia", duration_minutes: 60, price: 0, description: "Encuentro inicial para conocer el motivo de consulta." },
        { name: "Evaluación psicodiagnóstica", category: "Terapia", duration_minutes: 90, price: 0, description: "Proceso de evaluación con entrevistas y técnicas específicas." },
        { name: "Sesión de orientación a padres", category: "Terapia", duration_minutes: 60, price: 0, description: "Encuentro de orientación familiar y seguimiento." }
      ]
    },
    "nutrition" => {
      label: "Nutrición",
      category: "Salud",
      tone: "Profesional, claro y motivador. Evita promesas de resultados rápidos.",
      guidance: "Puede explicar preparación para la consulta, documentación necesaria y seguimiento, sin dar planes alimentarios personalizados por chat.",
      service_templates: [
        { name: "Primera consulta nutricional", category: "Nutrición", duration_minutes: 60, price: 0, description: "Evaluación inicial de hábitos, objetivos y antecedentes." },
        { name: "Control nutricional", category: "Nutrición", duration_minutes: 30, price: 0, description: "Seguimiento de evolución y ajustes del plan." },
        { name: "Consulta deportiva", category: "Nutrición", duration_minutes: 60, price: 0, description: "Orientación nutricional para actividad física y rendimiento." },
        { name: "Educación alimentaria familiar", category: "Nutrición", duration_minutes: 60, price: 0, description: "Consulta orientada a organización de comidas y hábitos familiares." }
      ]
    },
    "health" => {
      label: "Salud / consultorio",
      category: "Salud",
      tone: "Formal, prudente y orientado a resolver dudas administrativas.",
      guidance: "No brinda diagnósticos ni indicaciones médicas. Ante síntomas o urgencias, indica consultar directamente o acudir a guardia.",
      service_templates: [
        { name: "Consulta inicial", category: "Salud", duration_minutes: 30, price: 0, description: "Primera consulta profesional." },
        { name: "Control de seguimiento", category: "Salud", duration_minutes: 30, price: 0, description: "Turno de control y seguimiento." },
        { name: "Consulta virtual", category: "Salud", duration_minutes: 30, price: 0, description: "Atención remota coordinada con el profesional." },
        { name: "Evaluación profesional", category: "Salud", duration_minutes: 60, price: 0, description: "Evaluación específica según motivo de consulta." }
      ]
    },
    "wellness" => {
      label: "Bienestar / terapias",
      category: "Bienestar",
      tone: "Cálido, tranquilo y explicativo.",
      guidance: "Explica duración, preparación y recomendaciones generales sin prometer efectos terapéuticos garantizados.",
      service_templates: [
        { name: "Masaje relajante", category: "Corporal", duration_minutes: 60, price: 0, description: "Sesión de relajación corporal." },
        { name: "Reiki", category: "General", duration_minutes: 60, price: 0, description: "Sesión individual de armonización." },
        { name: "Clase personalizada", category: "General", duration_minutes: 60, price: 0, description: "Encuentro adaptado a objetivos personales." },
        { name: "Consulta de bienestar", category: "General", duration_minutes: 45, price: 0, description: "Espacio de orientación y seguimiento." }
      ]
    },
    "fitness" => {
      label: "Fitness / entrenamiento",
      category: "Fitness",
      tone: "Directo, motivador y profesional.",
      guidance: "Puede orientar sobre tipos de sesiones, preparación y requisitos, sin indicar rutinas clínicas ni reemplazar evaluación profesional.",
      service_templates: [
        { name: "Entrenamiento personalizado", category: "General", duration_minutes: 60, price: 0, description: "Sesión individual adaptada a objetivos." },
        { name: "Evaluación inicial", category: "General", duration_minutes: 45, price: 0, description: "Evaluación de punto de partida y objetivos." },
        { name: "Clase grupal", category: "General", duration_minutes: 60, price: 0, description: "Clase compartida con cupos limitados." },
        { name: "Planificación mensual", category: "General", duration_minutes: 30, price: 0, description: "Revisión y armado de objetivos de entrenamiento." }
      ]
    },
    "other" => {
      label: "Otro rubro",
      category: "General",
      tone: "Claro, profesional y adaptable al contexto cargado por el negocio.",
      guidance: "Usa el contexto del negocio como fuente principal y evita inventar información.",
      service_templates: [
        { name: "Consulta inicial", category: "General", duration_minutes: 60, price: 0, description: "Primer encuentro o servicio principal." },
        { name: "Turno de seguimiento", category: "General", duration_minutes: 30, price: 0, description: "Turno breve de seguimiento." },
        { name: "Servicio personalizado", category: "General", duration_minutes: 60, price: 0, description: "Servicio adaptado a cada cliente." }
      ]
    }
  }.freeze

  DAYS = [
    [ 1, "Lunes" ],
    [ 2, "Martes" ],
    [ 3, "Miércoles" ],
    [ 4, "Jueves" ],
    [ 5, "Viernes" ],
    [ 6, "Sábado" ],
    [ 0, "Domingo" ]
  ].freeze

  belongs_to :owner, class_name: "User", inverse_of: :business
  belongs_to :service_catalog_category, optional: true
  has_many :notification_deliveries, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :pets, dependent: :destroy, inverse_of: :business
  has_many :branches, dependent: :destroy
  has_many :employee_memberships, dependent: :destroy
  has_many :employees, through: :employee_memberships, source: :user
  has_many :service_categories, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :extras, dependent: :destroy
  has_many :payment_accounts, dependent: :destroy
  has_many :appointment_payments, dependent: :destroy
  has_one :mercado_pago_connection, dependent: :destroy
  has_many :bookable_resources, dependent: :destroy
  has_many :resource_blocks, dependent: :destroy
  has_many :availability_blocks, dependent: :destroy
  has_many :holidays, dependent: :destroy
  has_many :client_notes, dependent: :destroy
  has_many :booking_notes, dependent: :destroy
  has_many :booking_attachments, dependent: :destroy
  has_many :customer_reminders, dependent: :destroy
  has_many :waitlist_entries, foreign_key: :center_id, dependent: :destroy, inverse_of: :center
  has_many :sales_opportunities, dependent: :destroy
  has_many :sales_campaigns, dependent: :destroy
  has_many :sales_campaign_recipients, dependent: :destroy
  has_many :campaign_links, dependent: :destroy
  has_many :campaign_visits, dependent: :destroy
  has_many :booking_attributions, dependent: :destroy
  has_many :service_packs, dependent: :destroy
  has_many :customer_packs, dependent: :destroy
  has_many :pack_sessions, dependent: :destroy
  has_many :referrals, dependent: :destroy
  has_many :booking_intents, dependent: :destroy
  has_many :gift_cards, dependent: :destroy
  has_many :service_forms, dependent: :destroy
  has_many :service_form_questions, dependent: :destroy
  has_many :service_form_responses, dependent: :destroy
  has_many :content_templates, dependent: :destroy
  has_many :promotions, dependent: :destroy
  has_many :subscription_invoices, dependent: :destroy
  has_many :subscription_payment_proofs, dependent: :destroy
  has_many :subscription_checkout_payments, dependent: :destroy
  has_many :billing_reminders, dependent: :destroy
  has_many :super_admin_tasks, dependent: :destroy
  has_many :dynamic_pricing_rules, foreign_key: :center_id, dependent: :destroy, inverse_of: :center
  has_many :availability_rules, dependent: :destroy
  has_many :customer_profiles, dependent: :destroy
  has_many :customer_portal_access_tokens, dependent: :destroy
  has_many :provider_events, dependent: :destroy
  has_many :ai_api_usage_events, dependent: :nullify
  has_many :ai_chat_conversations, dependent: :destroy
  has_many :ai_context_imports, dependent: :destroy
  has_many :whatsapp_templates, class_name: "WhatsAppTemplate", dependent: :destroy
  has_many :email_delivery_logs, dependent: :nullify
  has_one :subscription, dependent: :destroy
  has_one :whatsapp_connection, dependent: :destroy
  has_many :whatsapp_contacts, dependent: :destroy
  has_many :whatsapp_events, dependent: :destroy
  has_many :whatsapp_deliveries, dependent: :destroy
  validates :simultaneous_capacity, numericality: { only_integer: true, in: 1..10 }, allow_nil: true
  validates :arrival_mode, inclusion: { in: %w[fixed continuous] }
  validates :whatsapp_reminder_hours, inclusion: { in: [ 2, 24 ] }
  validate :valid_arrival_times
  validate do
    if simultaneous_capacity.nil? && simultaneous_capacity_in_database.present?
      errors.add(:simultaneous_capacity, "debe estar entre 1 y 10")
    end
  end

  def valid_arrival_times
    unless arrival_times.is_a?(Hash) && arrival_times.all? { |day, times| day.to_s.match?(/\A[0-6]\z/) && times.is_a?(Array) && times.all? { |time| time.is_a?(String) && time.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/) } }
      errors.add(:arrival_times, "deben indicar horarios válidos por día")
    end
  end
  has_one_attached :logo
  purge_replaced_attached_blobs_for :logo

  attribute :business_kind, :string, default: "business"

  before_validation :ensure_slug, :normalize_business_kind, :ensure_public_site_mode, :ensure_trial_dates, :normalize_preferences, :sync_phone_fields
  after_create :create_default_subscription!, if: :billing_enabled?
  after_create :create_default_availability_rules!
  after_create :create_default_branch!
  after_create :create_default_whatsapp_templates!
  after_create :create_default_content_templates!
  after_create :create_default_payment_account_from_legacy!
  after_update_commit :broadcast_public_services_later, if: :public_profile_changed?

  validates :name, :slug, :trial_started_at, :trial_ends_at, presence: true
  validates :slug,
    uniqueness: { case_sensitive: false },
    format: { with: Slugs::GenerateUnique::FORMAT },
    length: { in: Slugs::GenerateUnique::MIN_LENGTH..Slugs::GenerateUnique::MAX_LENGTH },
    exclusion: { in: RESERVED_SLUGS }
  validates :setup_status, inclusion: { in: SETUP_STATUSES }
  validates :business_kind, inclusion: { in: BUSINESS_KINDS.keys }
  validates :industry, inclusion: { in: INDUSTRIES.keys }
  validates :public_font_style, inclusion: { in: PUBLIC_FONT_STYLES }, allow_blank: true
  validates :public_site_mode, inclusion: { in: PUBLIC_SITE_MODES.keys }
  validates :public_custom_css, length: { maximum: 20_000 }, allow_blank: true
  validates :public_custom_html, length: { maximum: PUBLIC_CUSTOM_HTML_MAX_LENGTH }, allow_blank: true
  validates :public_category_custom_html, length: { maximum: PUBLIC_CUSTOM_HTML_MAX_LENGTH }, allow_blank: true
  validates :custom_domain,
    uniqueness: { case_sensitive: false },
    format: { with: CUSTOM_DOMAIN_FORMAT },
    exclusion: { in: PLATFORM_HOSTS },
    allow_blank: true
  validate :custom_domain_is_present_when_enabled
  validates :cancellation_notice_hours, :rescheduling_notice_hours,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 168 }
  validate :logo_file_is_valid
  validate :preferences_are_valid
  normalizes :city, :province, :neighborhood, :address, :address_details, :contact_phone, :phone, :whatsapp_phone, :legal_name, :slogan, :public_headline, :public_email, :instagram_url, :website_url, :ai_context, :public_primary_color, :public_secondary_color, :public_accent_color, :public_font_style, :public_custom_css, :public_custom_html, :public_category_custom_html, with: ->(value) { value.to_s.strip.presence }
  normalizes :custom_domain, with: ->(value) { Business.normalize_custom_domain(value) }

  def self.slug_for(name)
    Slugs::GenerateUnique.normalize(name)
  end

  def self.normalize_custom_domain(value)
    value.to_s.strip.downcase
      .delete_prefix("https://")
      .delete_prefix("http://")
      .delete_suffix("/")
      .delete_suffix(".")
      .sub(/:\d+\z/, "")
      .presence
  end

  def self.find_by_custom_domain(host)
    domain = normalize_custom_domain(host)
    return if domain.blank?

    where(custom_domain: domain, custom_domain_enabled: true).first
  end

  def onboarding_complete?
    onboarding_completed_at.present?
  end

  def disabled?
    disabled_at.present? || owner.disabled?
  end

  def custom_domain_active?
    custom_domain.present? && custom_domain_enabled?
  end

  def trial_active?
    trial_ends_at.present? && trial_ends_at.future?
  end

  def trial_days_remaining
    return 0 unless trial_ends_at.present?

    [ (trial_ends_at.to_date - Time.zone.today).to_i, 0 ].max
  end

  def trial_grace_period_active?
    trial_ends_at.present? && trial_ends_at.past? && Time.current <= trial_ends_at + TRIAL_GRACE_DAYS.days
  end

  def subscription_active?
    return false unless billing_enabled?

    subscription&.active?
  end

  def billing_restricted?
    return false unless billing_enabled?

    subscription&.restricted?
  end

  def billing_suspended?
    return false unless billing_enabled?

    subscription&.suspended? || subscription&.cancelled?
  end

  def billing_pending_review?
    return false unless billing_enabled?

    subscription&.pending_review?
  end

  def access_active?
    return !disabled? unless billing_enabled?

    !disabled? && !billing_suspended? && (trial_active? || trial_grace_period_active? || subscription_active?)
  end

  def booking_available?
    onboarding_complete? && access_active? && !billing_restricted?
  end

  def cancellation_policy_text
    "Al agendar, aceptás la política de cambios de #{name}: la seña no se devuelve por cancelación. Reprogramación online hasta #{rescheduling_notice_hours} hs antes."
  end

  def premium?
    false
  end

  def basic?
    false
  end

  def business_kind_label
    BUSINESS_KINDS.fetch(business_kind, BUSINESS_KINDS.fetch("business"))
  end

  def industry_details
    INDUSTRIES.fetch(industry, INDUSTRIES.fetch("other"))
  end

  def industry_label
    service_catalog_category&.name.presence || industry_details.fetch(:label)
  end

  def industry_category
    industry_details.fetch(:category)
  end

  def industry_tone
    industry_details.fetch(:tone)
  end

  def industry_guidance
    industry_details.fetch(:guidance)
  end

  def service_templates
    return Grooming::Catalog.templates if industry == "dog_grooming"
    catalog_templates = service_categories.active.includes(service_catalog_category: :service_catalog_items).ordered.flat_map do |category|
      category.service_catalog_category&.service_templates
    end.compact
    return catalog_templates if catalog_templates.present?

    catalog_templates = service_catalog_category&.service_templates
    return catalog_templates if catalog_templates.present?

    industry_details.fetch(:service_templates)
  end

  def ai_industry_context
    <<~TEXT.squish
      Cuenta: #{business_kind_label}.
      Rubro: #{industry_label}.
      Tono recomendado: #{industry_tone}
      Reglas de rubro: #{industry_guidance}
    TEXT
  end

  def monthly_amount_cents
    billing_amount.total_amount_cents
  end

  def monthly_amount
    monthly_amount_cents / 100.0
  end

  def formatted_monthly_amount
    "$#{ActiveSupport::NumberHelper.number_to_delimited(monthly_amount_cents / 100, delimiter: ".")}/mes"
  end

  def active_professionals_count
    employee_memberships.available_for_booking.count
  end

  def subscription_details
    SUBSCRIPTION_DETAILS
  end

  def billing_amount
    Billing::MonthlyAmountCalculator.call(self)
  end

  def billing_status
    return "free" unless billing_enabled?
    return "suspended" if disabled?
    return subscription.normalized_status if subscription.present? && subscription.normalized_status.in?(%w[active payment_due pending_review overdue restricted suspended cancelled])
    return "trialing" if trial_active?
    return "payment_due" if trial_grace_period_active?

    "suspended"
  end

  def ai_chat_available?
    return false unless AI_CHAT_PUBLICLY_ENABLED

    access_active? && chatbot_enabled? && ai_context.present? && Ai::GeminiClient.available?
  end

  def preferences_with_defaults
    PREFERENCE_DEFAULTS.merge(preferences.to_h)
  end

  def chatbot_enabled?
    BOOLEAN.cast(preferences_with_defaults.fetch("chatbot_enabled"))
  end

  def deposits_enabled?
    BOOLEAN.cast(preferences_with_defaults.fetch("deposits_enabled"))
  end

  def deposit_percentage
    preferences_with_defaults.fetch("deposit_percentage").to_i
  end

  def enabled_payment_methods
    raw_preferences = preferences.to_h
    configured_methods = self.class.normalize_enabled_payment_methods(raw_preferences["enabled_payment_methods"])
    return configured_methods if configured_methods.any?

    inferred_enabled_payment_methods(raw_preferences)
  end

  def manual_transfer_payment_enabled?
    enabled_payment_methods.include?("manual_transfer")
  end

  def mercado_pago_payment_enabled?
    enabled_payment_methods.include?("mercado_pago")
  end

  def self.normalize_enabled_payment_methods(value)
    valid_methods = Array(value).map(&:to_s).map(&:strip).reject(&:blank?).select { |method| PAYMENT_METHODS.include?(method) }
    valid_methods.any? ? [ valid_methods.last ] : []
  end

  def public_booking_allow_professional_selection?
    BOOLEAN.cast(preferences_with_defaults.fetch("public_booking_allow_professional_selection"))
  end

  def public_booking_show_team_members?
    BOOLEAN.cast(preferences_with_defaults.fetch("public_booking_show_team_members"))
  end

  def public_booking_assignment_strategy
    self.class.normalize_public_booking_assignment_strategy(preferences_with_defaults.fetch("public_booking_assignment_strategy"))
  end

  def public_booking_assignment_strategy_label
    PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_LABELS.fetch(public_booking_assignment_strategy)
  end

  def self.normalize_public_booking_assignment_strategy(value)
    normalized = value.to_s.strip
    PUBLIC_BOOKING_ASSIGNMENT_STRATEGIES.include?(normalized) ? normalized : PUBLIC_BOOKING_ASSIGNMENT_STRATEGY_DEFAULT
  end

  def deposit_percentage_options
    DEPOSIT_PERCENTAGE_OPTIONS
  end

  def deposit_summary
    deposits_enabled? ? "#{deposit_percentage}% de seña" : "Sin seña"
  end

  def deposit_alias
    preferences_with_defaults.fetch("deposit_alias").to_s
  end

  def deposit_account
    preferences_with_defaults.fetch("deposit_account").to_s
  end

  def deposit_holder
    preferences_with_defaults.fetch("deposit_holder").to_s
  end

  def deposit_tax_id
    preferences_with_defaults.fetch("deposit_tax_id").to_s
  end

  def deposit_instructions
    preferences_with_defaults.fetch("deposit_instructions").to_s
  end

  def deposit_payment_link
    preferences_with_defaults.fetch("deposit_payment_link").to_s
  end

  def primary_payment_account
    PaymentAccount.primary_for(self)
  end

  def payment_accounts_configured?
    payment_accounts.active.exists?
  end

  def legacy_payment_account_details
    lines = []
    lines << "Alias: #{deposit_alias}" if deposit_alias.present?
    lines << "CBU/CVU: #{deposit_account}" if deposit_account.present?
    lines << "Titular: #{deposit_holder}" if deposit_holder.present?
    lines << "CUIT/CUIL: #{deposit_tax_id}" if deposit_tax_id.present?
    lines << "Link de pago: #{deposit_payment_link}" if deposit_payment_link.present?
    lines << "" << deposit_instructions if deposit_instructions.present?
    lines.join("\n").presence
  end

  def setup_warnings
    Array(preferences_with_defaults.fetch("setup_warnings")).map(&:to_s).compact_blank
  end

  def manual_deposit_configured?
    payment_accounts_configured? || legacy_payment_account_details.present?
  end

  def mercado_pago_connected?
    mercado_pago_connection&.available_for_current_environment?
  end

  def team_features_available?
    true
  end

  def initials
    name.to_s.split.first(2).map { |part| part.first&.upcase }.join.presence || "TU"
  end

  def public_location
    location_parts(include_address_details: true).join(", ").presence || "Ubicación a confirmar"
  end

  def public_location_configured?
    location_parts(include_address_details: true).any?
  end

  def location_search_address
    location_parts(include_address_details: false).join(", ")
  end

  def public_phone
    phone.presence || contact_phone.presence || whatsapp_phone
  end

  def clean_phone
    PhoneNumber.normalize(public_phone).delete_prefix("+")
  end

  def contact_whatsapp_link
    return "" if clean_phone.blank?

    "https://wa.me/#{clean_phone}?text=Hola!%20Quiero%20hacer%20una%20consulta"
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def google_maps_directions_url
    destination = if geocoded?
      "#{latitude},#{longitude}"
    else
      public_location
    end
    return "" if destination.blank? || destination == "Ubicación a confirmar"

    "https://www.google.com/maps/dir/?api=1&destination=#{CGI.escape(destination)}&travelmode=driving"
  end

  def public_city
    [ neighborhood, city, province, address ].compact_blank.first || "Argentina"
  end

  def public_intro
    public_headline.presence || "Elegí el servicio, encontrá un horario disponible y reservá tu turno en pocos pasos."
  end

  def public_site_mode_label
    PUBLIC_SITE_MODES.fetch(public_site_mode, PUBLIC_SITE_MODES.fetch(PUBLIC_SITE_MODE_DEFAULT))
  end

  def booking_link_mode?
    public_site_mode != "full_website"
  end

  def full_website_mode?
    public_site_mode == "full_website"
  end

  def public_booking_headline
    return slogan if slogan.present?

    case industry
    when "dog_grooming"
      "El cuidado de tu mascota empieza acá"
    when "barber"
      "Tu próximo corte, con turno confirmado"
    when "nutrition"
      "Tu consulta nutricional, simple de reservar"
    when "nails"
      "Tus uñas, con turno confirmado"
    else
      "Tu momento de bienestar empieza acá"
    end
  end

  def public_booking_subtitle
    public_intro
  end

  def public_service_selection_title
    case industry
    when "dog_grooming"
      "¿Qué servicio necesita tu mascota?"
    when "barber"
      "¿Qué servicio de barbería querés reservar?"
    when "nutrition"
      "¿Qué consulta querés agendar?"
    when "nails"
      "¿Qué servicio de uñas querés hacerte?"
    else
      "¿Qué tratamiento querés realizarte?"
    end
  end

  def public_service_selection_hint
    case industry
    when "dog_grooming"
      "Podés revisar la duración, el precio y los cuidados de cada servicio antes de reservar."
    when "nutrition"
      "Podés revisar la duración y modalidad antes de elegir."
    else
      "Podés revisar la duración y el precio antes de elegir."
    end
  end

  def public_service_search_placeholder
    case industry
    when "dog_grooming"
      "Buscar baño, corte o higiene"
    when "barber"
      "Buscar corte o barba"
    when "nutrition"
      "Buscar consulta"
    when "nails"
      "Buscar servicio de uñas"
    else
      "Buscar tratamiento"
    end
  end

  def public_chat_services_detail
    case industry
    when "dog_grooming"
      "Ver baños, cortes y cuidados"
    when "barber"
      "Ver cortes, barba y combos"
    when "nutrition"
      "Ver consultas y controles"
    when "nails"
      "Ver técnicas, retiro y diseño"
    else
      "Consultar tratamientos disponibles"
    end
  end

  def weekly_hours_summary
    active_rules = availability_rules.select(&:active?).sort_by(&:weekday)
    return "Horarios a confirmar" if active_rules.blank?

    ranges = active_rules.group_by { |rule| [ rule.start_time.strftime("%H:%M"), rule.end_time.strftime("%H:%M") ] }
    ranges.map do |(start_time, end_time), rules|
      "#{day_range_label(rules.map(&:weekday))} de #{start_time} a #{end_time}"
    end.to_sentence(two_words_connector: " y ", last_word_connector: " y ")
  end

  def public_url
    PublicUrls.url(:business, self)
  end

  def whatsapp_contact_link
    PhoneNumber.whatsapp_link(whatsapp_phone.presence || contact_phone)
  end

  def inferred_enabled_payment_methods(raw_preferences = preferences.to_h)
    legacy_collection_method = raw_preferences["payment_collection_method"].to_s
    return [ "mercado_pago" ] if legacy_collection_method == "mercado_pago" || mercado_pago_connected?
    return [ "manual_transfer" ] if legacy_collection_method.blank? || legacy_collection_method == "manual_proof" || payment_accounts_configured?

    [ "manual_transfer" ]
  end

  private
    def custom_domain_is_present_when_enabled
      errors.add(:custom_domain, "es obligatorio para activarlo") if custom_domain_enabled? && custom_domain.blank?
    end

    def ensure_slug
      self.slug = self.class.slug_for(slug.presence || name)
    end

    def normalize_business_kind
      self.business_kind = "business"
    end

    def ensure_public_site_mode
      self.public_site_mode = PUBLIC_SITE_MODE_DEFAULT unless PUBLIC_SITE_MODES.key?(public_site_mode)
    end

    def ensure_trial_dates
      self.trial_started_at ||= created_at || Time.current
      self.trial_ends_at ||= trial_started_at + subscription_details.fetch(:trial_days).days
    end

    def normalize_preferences
      raw_preferences = preferences.to_h
      self.preferences = PREFERENCE_DEFAULTS.merge(
        "chatbot_enabled" => BOOLEAN.cast(raw_preferences.fetch("chatbot_enabled", PREFERENCE_DEFAULTS.fetch("chatbot_enabled"))),
        "deposits_enabled" => BOOLEAN.cast(raw_preferences.fetch("deposits_enabled", PREFERENCE_DEFAULTS.fetch("deposits_enabled"))),
        "deposit_percentage" => raw_preferences.fetch("deposit_percentage", PREFERENCE_DEFAULTS.fetch("deposit_percentage")).to_i,
        "enabled_payment_methods" => self.class.normalize_enabled_payment_methods(raw_preferences["enabled_payment_methods"]).presence || inferred_enabled_payment_methods(raw_preferences),
        "public_booking_allow_professional_selection" => BOOLEAN.cast(raw_preferences.fetch("public_booking_allow_professional_selection", PREFERENCE_DEFAULTS.fetch("public_booking_allow_professional_selection"))),
        "public_booking_show_team_members" => BOOLEAN.cast(raw_preferences.fetch("public_booking_show_team_members", PREFERENCE_DEFAULTS.fetch("public_booking_show_team_members"))),
        "public_booking_assignment_strategy" => self.class.normalize_public_booking_assignment_strategy(raw_preferences.fetch("public_booking_assignment_strategy", PREFERENCE_DEFAULTS.fetch("public_booking_assignment_strategy"))),
        "deposit_alias" => raw_preferences.fetch("deposit_alias", PREFERENCE_DEFAULTS.fetch("deposit_alias")).to_s.strip,
        "deposit_account" => raw_preferences.fetch("deposit_account", PREFERENCE_DEFAULTS.fetch("deposit_account")).to_s.strip,
        "deposit_holder" => raw_preferences.fetch("deposit_holder", PREFERENCE_DEFAULTS.fetch("deposit_holder")).to_s.strip,
        "deposit_tax_id" => raw_preferences.fetch("deposit_tax_id", PREFERENCE_DEFAULTS.fetch("deposit_tax_id")).to_s.strip,
        "deposit_instructions" => raw_preferences.fetch("deposit_instructions", PREFERENCE_DEFAULTS.fetch("deposit_instructions")).to_s.strip,
        "deposit_payment_link" => raw_preferences.fetch("deposit_payment_link", PREFERENCE_DEFAULTS.fetch("deposit_payment_link")).to_s.strip,
        "setup_warnings" => Array(raw_preferences.fetch("setup_warnings", PREFERENCE_DEFAULTS.fetch("setup_warnings"))).map(&:to_s).compact_blank
      )
    end

    def sync_phone_fields
      if will_save_change_to_phone? && !will_save_change_to_contact_phone? && phone.present?
        self.contact_phone = phone
      elsif contact_phone.present?
        self.phone = contact_phone
      elsif phone.present?
        self.contact_phone = phone
      end
    end

    def create_default_payment_account_from_legacy!
      return if payment_accounts.exists?
      return if legacy_payment_account_details.blank?

      payment_accounts.create!(
        name: "Cuenta principal",
        details: legacy_payment_account_details,
        primary_account: true,
        active: true
      )
    end

    def preferences_are_valid
      errors.add(:preferences, "debe tener chatbot_enabled booleano") unless preferences.fetch("chatbot_enabled").in?([ true, false ])
      errors.add(:preferences, "debe tener deposits_enabled booleano") unless preferences.fetch("deposits_enabled").in?([ true, false ])
      errors.add(:preferences, "debe tener public_booking_allow_professional_selection booleano") unless preferences.fetch("public_booking_allow_professional_selection").in?([ true, false ])
      errors.add(:preferences, "debe tener public_booking_show_team_members booleano") unless preferences.fetch("public_booking_show_team_members").in?([ true, false ])
      errors.add(:preferences, "debe tener métodos de pago válidos") if enabled_payment_methods.blank?
      errors.add(:preferences, "debe tener una estrategia de asignación válida") unless PUBLIC_BOOKING_ASSIGNMENT_STRATEGIES.include?(public_booking_assignment_strategy)
      return if DEPOSIT_PERCENTAGE_OPTIONS.include?(deposit_percentage)

      errors.add(:preferences, "debe usar un porcentaje de seña entre 10 y 100")
    end

    def logo_file_is_valid
      return unless logo.attached?

      unless logo.blob.content_type.in?(LOGO_CONTENT_TYPES)
        errors.add(:logo, "debe ser una imagen")
      end

      if logo.blob.byte_size > LOGO_MAX_SIZE
        errors.add(:logo, "no puede superar 5 MB")
      end
    end

    def create_default_subscription!
      details = SUBSCRIPTION_DETAILS
      trial_end = trial_ends_at&.to_date
      create_subscription!(
        external_reference: "business-#{id}-#{SecureRandom.hex(6)}",
        amount_cents: billing_amount.total_amount_cents,
        billing_period_months: 1,
        trial_started_on: trial_started_at&.to_date,
        trial_ends_on: trial_end,
        next_due_on: trial_end,
        grace_ends_on: trial_end&.+(15)
      )
    end

    def create_default_availability_rules!
      DAYS.each do |weekday, _name|
        availability_rules.create!(
          weekday: weekday,
          active: weekday.in?([ 1, 2, 3, 4, 5 ]),
          start_time: "09:00",
          end_time: "18:00"
        )
      end
    end

    def create_default_branch!
      branches.find_or_create_by!(name: "Principal") do |branch|
        branch.address = address
        branch.address_details = address_details
        branch.city = city
        branch.province = province
        branch.latitude = latitude
        branch.longitude = longitude
        branch.phone = contact_phone
      end
    end

    def create_default_whatsapp_templates!
      WhatsAppTemplate.ensure_defaults_for!(self)
    end

    def create_default_content_templates!
      ContentTemplate.ensure_defaults_for!(self)
    end

    def day_range_label(weekdays)
      names = DAYS.to_h
      ordered = weekdays.sort
      return names.fetch(ordered.first) if ordered.one?

      if ordered == (ordered.first..ordered.last).to_a
        "#{names.fetch(ordered.first)} a #{names.fetch(ordered.last)}"
      else
        ordered.map { |weekday| names.fetch(weekday) }.to_sentence(two_words_connector: " y ", last_word_connector: " y ")
      end
    end

    def location_parts(include_address_details:)
      address_part = address_without_location_suffix
      parts = [ address_part ]
      parts << address_details if include_address_details
      deduplicate_location_parts(parts + [ neighborhood, city, province ])
    end

    def address_without_location_suffix
      segments = address.to_s.split(",").map { |part| part.squish.presence }.compact
      suffix_keys = [ neighborhood, city, province, "Argentina" ].compact_blank.map { |part| location_part_key(part) }

      while segments.many? && suffix_keys.include?(location_part_key(segments.last))
        segments.pop
      end

      segments.join(", ")
    end

    def deduplicate_location_parts(parts)
      seen_keys = []
      parts.each_with_object([]) do |part, cleaned|
        value = part.to_s.squish.presence
        next if value.blank?

        key = location_part_key(value)
        next if seen_keys.include?(key)

        cleaned << value
        value.split(",").each do |segment|
          segment_key = location_part_key(segment)
          seen_keys << segment_key if segment_key.present?
        end
      end
    end

    def location_part_key(value)
      I18n.transliterate(value.to_s).downcase.squish
    end

    def public_profile_changed?
      (saved_changes.keys & %w[
        name slug business_kind industry contact_phone whatsapp_phone phone public_email instagram_url website_url
        address city province neighborhood slogan public_headline cancellation_notice_hours rescheduling_notice_hours preferences
        public_site_mode public_custom_css public_custom_html public_category_custom_html public_primary_color public_secondary_color public_accent_color public_font_style
        ai_chat_enabled disabled_at
      ]).any?
    end

    def broadcast_public_services_later
      PublicBooking::BroadcastServicesJob.perform_later(id)
    end
end
