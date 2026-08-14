class WhatsAppTemplate < ApplicationRecord
  KEYS = %w[
    booking_confirmation
    deposit_request
    proof_request
    proof_rejected
    appointment_reminder
    gap_offer
    customer_reactivation
    waitlist_offer
    booking_reschedule
    booking_cancelled
    public_booking_link
    sales_follow_up
    inactive_customer_reactivation
    pack_renewal
    referral_invite
    abandoned_booking_recovery
    gift_card_offer
    gift_card_delivery
    marketing_photo_consent
  ].freeze

  DEFAULTS = {
    "booking_confirmation" => {
      name: "Confirmación de turno",
      body: "Hola {{customer_name}},\n✅ Turno confirmado con {{business_name}}\nServicio: {{service_name}}\nFecha y hora: {{booking_date}}, {{booking_time}}\nPodes gestionar tus turnos aca: {{customer_portal_link}}"
    },
    "deposit_request" => {
      name: "Pedido de seña",
      body: "Hola {{customer_name}}, para reservar {{service_name}} te pedimos una seña de {{deposit_amount}}. Podés transferir a {{payment_alias}} y subir el comprobante acá: {{booking_link}}.\n\nTambién podés ver, cancelar o reprogramar tus turnos acá: {{customer_portal_link}}"
    },
    "proof_request" => {
      name: "Pedir comprobante más claro",
      body: "Hola {{customer_name}}, ¿podés enviarnos un comprobante más claro de la seña para tu turno de {{service_name}}?\n\nTambién podés ver, cancelar o reprogramar tus turnos acá: {{customer_portal_link}}"
    },
    "proof_rejected" => {
      name: "Comprobante rechazado",
      body: "Hola {{customer_name}}, no pudimos aprobar el comprobante de la seña para {{service_name}}. Podés subir uno nuevo acá: {{booking_link}}.\n\nTambién podés ver, cancelar o reprogramar tus turnos acá: {{customer_portal_link}}"
    },
    "appointment_reminder" => {
      name: "Recordatorio de turno",
      body: "Hola {{customer_name}}, te recordamos tu turno para {{service_name}} el {{booking_date}} a las {{booking_time}} en {{business_name}}.\n\nTambién podés ver, cancelar o reprogramar tus turnos acá: {{customer_portal_link}}"
    },
    "gap_offer" => {
      name: "Ofrecer hueco libre",
      body: "Hola {{customer_name}}, se liberó un horario para {{service_name}} el {{gap_date}} a las {{gap_time}}. ¿Querés que te lo reserve?"
    },
    "customer_reactivation" => {
      name: "Reactivar clienta",
      body: "Hola {{customer_name}}, ¿cómo estás? Hace un tiempo que no venís a {{business_name}}. Esta semana tenemos algunos turnos disponibles."
    },
    "waitlist_offer" => {
      name: "Ofrecer a lista de espera",
      body: "Hola {{customer_name}}, se liberó un horario para {{service_name}} el {{gap_date}} a las {{gap_time}}. ¿Querés que te lo reserve?"
    },
    "booking_reschedule" => {
      name: "Reprogramar turno",
      body: "Hola {{customer_name}}, te escribimos de {{business_name}} para coordinar una reprogramación de tu turno de {{service_name}}.\n\nTambién podés ver, cancelar o reprogramar tus turnos acá: {{customer_portal_link}}"
    },
    "booking_cancelled" => {
      name: "Avisar cancelación",
      body: "Hola {{customer_name}}, te avisamos que tu turno de {{service_name}} del {{booking_date}} a las {{booking_time}} quedó cancelado.\n\nTambién podés ver, cancelar o reprogramar tus turnos acá: {{customer_portal_link}}"
    },
    "public_booking_link" => {
      name: "Enviar link público",
      body: "Hola {{customer_name}}, te compartimos el link para reservar en {{business_name}}: {{public_booking_link}}"
    },
    "sales_follow_up" => {
      name: "Seguimiento comercial",
      body: "Hola {{customer_name}}, ¿cómo estás? Ya sería buen momento para repetir {{service_name}}. Te dejo el link para reservar: {{service_link}}"
    },
    "inactive_customer_reactivation" => {
      name: "Reactivar clienta inactiva",
      body: "Hola {{customer_name}}, hace un tiempo que no venís a {{business_name}}. Esta semana tenemos horarios para {{service_name}}. ¿Querés que te pase opciones?"
    },
    "pack_renewal" => {
      name: "Renovar pack",
      body: "Hola {{customer_name}}, te queda {{remaining_sessions}} sesión de {{pack_name}}. ¿Querés que coordinemos la próxima o renovamos el pack?"
    },
    "referral_invite" => {
      name: "Invitar referida",
      body: "Hola {{customer_name}}, si tenés una amiga que quiera venir a {{business_name}}, podés pasarle este link: {{public_booking_link}}. Si reserva, te dejamos registrado el beneficio."
    },
    "abandoned_booking_recovery" => {
      name: "Recuperar reserva pendiente",
      body: "Hola {{customer_name}}, vimos que quedó pendiente tu reserva para {{service_name}}. ¿Querés que te ayudemos a confirmarla?"
    },
    "gift_card_offer" => {
      name: "Ofrecer gift card",
      body: "Hola {{customer_name}}, en {{business_name}} tenemos gift cards para regalar tratamientos. ¿Querés que te pase opciones?"
    },
    "gift_card_delivery" => {
      name: "Enviar gift card",
      body: "Hola {{customer_name}}, te compartimos tu gift card de {{business_name}}: {{gift_card_code}}. Para reservar podés usar este link: {{public_booking_link}}"
    },
    "marketing_photo_consent" => {
      name: "Pedir permiso para usar foto",
      body: "Hola {{customer_name}}, ¿nos autorizás a usar la foto del resultado de {{service_name}} en nuestras redes, sin mostrar datos personales?"
    }
  }.freeze

  VARIABLES = %w[
    customer_name
    business_name
    service_name
    booking_date
    booking_time
    professional_name
    deposit_amount
    payment_alias
    public_booking_link
    service_link
    campaign_link
    pack_name
    remaining_sessions
    gift_card_code
    booking_link
    customer_portal_link
    business_whatsapp
    address
    gap_date
    gap_time
  ].freeze

  belongs_to :business

  validates :key, :name, :body, presence: true
  validates :key, inclusion: { in: KEYS }
  validates :key, uniqueness: { scope: :business_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:key) }

  def self.ensure_defaults_for!(business)
    DEFAULTS.each do |key, attrs|
      business.whatsapp_templates.find_or_create_by!(key: key) do |template|
        template.name = attrs.fetch(:name)
        template.body = attrs.fetch(:body)
        template.active = true
        template.system_default = true
      end
    end
  end

  def restore_default!
    attrs = DEFAULTS.fetch(key)
    update!(name: attrs.fetch(:name), body: attrs.fetch(:body), active: true, system_default: true)
  end
end
