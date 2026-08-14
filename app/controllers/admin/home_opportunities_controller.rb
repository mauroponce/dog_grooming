module Admin
  class HomeOpportunitiesController < BaseController
    def create
      records = opportunity_params.fetch(:items, []).filter_map { |item| register_opportunity_contact(item) }

      render json: { ok: true, count: records.size }
    end

    private
      def opportunity_params
        params.permit(items: [
          :customer_profile_id,
          :service_id,
          :employee_membership_id,
          :opportunity_type,
          :starts_at,
          :ends_at,
          :message,
          :result,
          :source
        ])
      end

      def register_opportunity_contact(item)
        customer = @business.customer_profiles.find_by(id: item[:customer_profile_id])
        return if customer.blank?

        service = @business.services.find_by(id: item[:service_id])
        employee = @business.employee_memberships.find_by(id: item[:employee_membership_id])
        opportunity = find_or_build_opportunity(item, customer, service, employee)

        opportunity.assign_attributes(
          title: opportunity_title(customer, service),
          body: item[:message].to_s,
          score: score_for(item),
          due_at: parsed_time(item[:starts_at]),
          metadata: opportunity.metadata.merge(metadata_for(item)),
          service: service,
          employee_membership: employee
        )

        apply_result(opportunity, item[:result])
        opportunity.save!
        opportunity
      end

      def find_or_build_opportunity(item, customer, service, employee)
        starts_at = parsed_time(item[:starts_at])
        type = opportunity_type_for(item)
        metadata_starts_at = starts_at&.iso8601

        @business.sales_opportunities
          .where(customer_profile: customer, service: service, opportunity_type: type)
          .where("metadata ->> 'gap_starts_at' = ?", metadata_starts_at.to_s)
          .order(created_at: :desc)
          .first || @business.sales_opportunities.new(
            customer_profile: customer,
            service: service,
            employee_membership: employee,
            opportunity_type: type
          )
      end

      def apply_result(opportunity, result)
        case result.to_s
        when "dismissed", "no puede"
          opportunity.status = "dismissed"
          opportunity.dismissed_at ||= Time.current
        else
          opportunity.status = "contacted"
          opportunity.contacted_at ||= Time.current
        end
      end

      def metadata_for(item)
        {
          "source" => item[:source].presence || "admin_home",
          "result" => item[:result].presence || "contacted",
          "gap_starts_at" => parsed_time(item[:starts_at])&.iso8601,
          "gap_ends_at" => parsed_time(item[:ends_at])&.iso8601,
          "message" => item[:message].to_s
        }.compact
      end

      def opportunity_title(customer, service)
        service_name = service&.name.presence || "un servicio"
        customer_name = customer.name.presence || customer.phone
        "Ofrecer #{service_name} a #{customer_name}"
      end

      def opportunity_type_for(item)
        item[:opportunity_type].presence_in(SalesOpportunity::TYPES) ||
          (item[:source].to_s == "waitlist" ? "waitlist_match" : "fillable_gap")
      end

      def score_for(item)
        return 95 if item[:source].to_s == "waitlist"
        return 86 if item[:source].to_s == "follow_up"
        return 72 if item[:source].to_s == "frequent"

        60
      end

      def parsed_time(value)
        Time.zone.parse(value.to_s) if value.present?
      rescue ArgumentError, TypeError
        nil
      end
  end
end
