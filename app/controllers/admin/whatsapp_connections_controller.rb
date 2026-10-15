module Admin
  class WhatsAppConnectionsController < BaseController
    def create
      expected = session.delete(:whatsapp_signup_state)
      raise ArgumentError, "La conexión venció. Volvé a abrir Configuración." unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, params[:state].to_s)

      connection = WhatsApp::ConnectBusiness.call(business: @business, code: params.require(:code), waba_id: params.require(:waba_id), phone_number_id: params.require(:phone_number_id))
      WhatsApp::Templates.ensure!(connection)
      redirect_to admin_settings_path, notice: "WhatsApp Business conectado. Verificá las plantillas antes de activar notificaciones PRO."
    rescue WhatsApp::CloudClient::Error, ArgumentError, KeyError, ActiveRecord::RecordInvalid
      redirect_to admin_settings_path, alert: "No pudimos conectar WhatsApp. Revisá la habilitación de coexistencia en Meta e intentá nuevamente."
    end

    def update
      connection = @business.whatsapp_connection
      raise ArgumentError unless connection&.connected?
      WhatsApp::Templates.ensure!(connection)

      templates = WhatsApp::CloudClient.new.get!("#{connection.waba_id}/message_templates?fields=name,status,language,category&limit=100", token: connection.access_token).fetch("data")
      approved = [ connection.confirmation_template, connection.reminder_template ].all? do |name|
        templates.any? { |item| item["name"] == name && item["language"] == connection.template_language && item["status"] == "APPROVED" && item["category"] == "UTILITY" }
      end
      connection.update!(templates_approved: approved)
      redirect_to admin_settings_path, notice: approved ? "Plantillas de utilidad aprobadas." : "Las dos plantillas todavía no están aprobadas por Meta."
    rescue WhatsApp::CloudClient::Error, ArgumentError, KeyError
      redirect_to admin_settings_path, alert: "No pudimos verificar las plantillas de Meta."
    end

    def destroy
      @business.whatsapp_connection&.update!(access_token_ciphertext: nil, disconnected_at: Time.current, templates_approved: false)
      redirect_to admin_settings_path, notice: "Automatización de WhatsApp desconectada."
    end
  end
end
