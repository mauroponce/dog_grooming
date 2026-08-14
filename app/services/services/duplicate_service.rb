module Services
  class DuplicateService
    def initialize(service:)
      @service = service
    end

    def call
      copy = nil
      service.transaction do
        copy = service.dup
        copy.name = "Copia de #{service.name}"
        copy.active = false
        copy.visibility_mode = "hidden"
        copy.popular = false
        copy.sort_order = service.sort_order.to_i + 1
        copy.save!
        copy.bookable_resource_ids = service.bookable_resource_ids
        copy.employee_membership_ids = service.employee_membership_ids
        service.service_tags.each do |tag|
          copy.service_tags.create!(name: tag.name, tag_type: tag.tag_type)
        end
      end
      copy
    end

    private
      attr_reader :service
  end
end
