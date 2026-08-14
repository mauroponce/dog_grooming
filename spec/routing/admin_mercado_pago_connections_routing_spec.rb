require "rails_helper"

RSpec.describe Admin::MercadoPagoConnectionsController, type: :routing do
  it "routes the canonical Mercado Pago OAuth callback under admin settings" do
    expect(get: "/admin/configuracion/mercadopago/callback").to route_to(
      controller: "admin/mercado_pago_connections",
      action: "callback"
    )
  end

  it "keeps the legacy Mercado Pago OAuth callback route as an alias" do
    expect(get: "/admin/mercado-pago/callback").to route_to(
      controller: "admin/mercado_pago_connections",
      action: "callback"
    )
  end
end
