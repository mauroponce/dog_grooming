require "rails_helper"

RSpec.describe Storage::ObjectKeyBuilder do
  describe ".deposit_receipt" do
    it "stores receipts under the business slug and comprobantes folder" do
      business = Business.new(slug: "mauro-estetica")
      appointment = Appointment.new(id: 123, business: business, starts_at: Time.zone.local(2026, 6, 30, 15, 30))

      key = described_class.deposit_receipt(appointment, filename: "Comprobante Seña.pdf")

      expect(key).to match(%r{\Amauro-estetica/comprobantes/2026-06/appointment-123/20260630153000-comprobante-sena-[a-f0-9]{16}\.pdf\z})
    end
  end

  describe ".business_logo" do
    it "stores logos under the business slug and logo folder" do
      business = Business.new(id: 12, slug: "mauro-estetica")
      business.created_at = Time.zone.local(2026, 6, 30, 15, 30)

      key = described_class.business_logo(business, filename: "Logo Aura.webp")

      expect(key).to match(%r{\Amauro-estetica/imagenes/logos/\d{4}-\d{2}/business-12/\d{14}-logo-aura-[a-f0-9]{16}\.webp\z})
    end
  end

  describe ".service_image" do
    it "stores service gallery images under the business slug and service gallery folder" do
      business = Business.new(id: 12, slug: "mauro-estetica")
      service = Service.new(id: 44, business: business)

      key = described_class.service_image(service, filename: "Corte Premium.webp")

      expect(key).to match(%r{\Amauro-estetica/imagenes/servicios/galeria/\d{4}-\d{2}/service-44/\d{14}-corte-premium-[a-f0-9]{16}\.webp\z})
    end
  end

  describe ".service_category_cover" do
    it "stores category cover images under the business slug and category images folder" do
      business = Business.new(id: 12, slug: "mauro-estetica")
      category = ServiceCategory.new(id: 44, business: business)

      key = described_class.service_category_cover(category, filename: "Masajes relax.webp")

      expect(key).to match(%r{\Amauro-estetica/imagenes/categorias/\d{4}-\d{2}/service_category-44/\d{14}-masajes-relax-[a-f0-9]{16}\.webp\z})
    end
  end
end
