module Admin
  class WhatsAppConnectionsController < BaseController
    def create
      signup = session.delete(:whatsapp_signup)&.with_indifferent_access
      valid = signup && signup[:business_id] == @business.id && signup[:user_id] == current_user.id &&
        signup[:issued_at].to_i.between?(15.minutes.ago.to_i, Time.current.to_i) &&
        ActiveSupport::SecurityUtils.secure_compare(signup[:state].to_s, params[:state].to_s)
      raise ArgumentError, "La conexión venció. Volvé a abrir Configuración." unless valid

      WhatsApp::ConnectBusiness.call(business: @business, code: params.require(:code), event: params[:signup_event], waba_id: params[:waba_id], phone_number_id: params[:phone_number_id])
      redirect_to admin_settings_path, notice: "WhatsApp conectado en coexistencia. La automatización sigue desactivada."
    rescue WhatsApp::CloudClient::Error => error
      suffix = error.code ? " Meta: código #{error.code.to_i}#{error.subcode ? "/#{error.subcode.to_i}" : ''}." : ""
      redirect_to admin_settings_path, alert: "Meta no pudo autorizar la conexión. Revisá permisos avanzados y la configuración v4; iniciá una conexión nueva.#{suffix}"
    rescue ArgumentError, KeyError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to admin_settings_path, alert: "No pudimos conectar WhatsApp. Revisá la habilitación de coexistencia en Meta e intentá nuevamente."
    end

    def update
      connection = @business.whatsapp_connection
      raise ArgumentError unless connection&.connected?
      phone = WhatsApp::CloudClient.new.get!("#{connection.phone_number_id}?fields=id,is_on_biz_app,platform_type", token: connection.access_token)
      raise ArgumentError unless phone["id"] == connection.phone_number_id && phone["is_on_biz_app"] == true && phone["platform_type"] == "CLOUD_API"

      connection.update!(verified_at: Time.current)
      redirect_to admin_settings_path, notice: "Conexión de WhatsApp Business verificada."
    rescue WhatsApp::CloudClient::Error => error
      connection&.update!(authorization_failed_at: Time.current, automation_enabled: false) if error.authorization_error?
      redirect_to admin_settings_path, alert: "No pudimos verificar la conexión. Si los permisos vencieron, volvé a conectar tu cuenta."
    rescue ArgumentError, KeyError
      redirect_to admin_settings_path, alert: "No pudimos verificar la coexistencia. Volvé a conectar WhatsApp Business."
    end

    def destroy
      @business.whatsapp_connection&.disconnect!
      redirect_to admin_settings_path, notice: "CitaPet desconectado localmente. Para desvincular también la plataforma, usá Configuración → Cuenta → Plataforma empresarial en WhatsApp Business."
    end
  end
end
