class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
  end

  def registration_closed
    redirect_to root_path(anchor: "contacto"), alert: "Por ahora creamos las cuentas desde Dog Grooming. Escribinos y te damos el alta."
  end

  def registration_closed_json
    render json: {
      available: false,
      message: "Por ahora creamos las cuentas desde Dog Grooming."
    }, status: :gone
  end
end
