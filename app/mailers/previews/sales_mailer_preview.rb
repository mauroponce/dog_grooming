class SalesMailerPreview < ActionMailer::Preview
  def daily_sales_digest
    SalesMailer.daily_sales_digest(sample_business)
  end

  def weekly_sales_digest
    SalesMailer.weekly_sales_digest(sample_business)
  end

  def campaign_summary
    SalesMailer.campaign_summary(sample_campaign)
  end

  private
    def sample_business
      Business.first || raise("Creá un negocio o corré seeds para ver previews de SalesMailer.")
    end

    def sample_campaign
      sample_business.sales_campaigns.first || sample_business.sales_campaigns.new(
        name: "Turnos libres de esta semana",
        objective: "reactivate_customers",
        status: "active",
        message_template: "Hola {{customer_name}}, esta semana tenemos turnos disponibles en {{business_name}}."
      )
    end
end
