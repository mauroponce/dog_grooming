module Appointments
  class LinkCustomer
    def self.call(appointment:, customer:, pet:, actor:)
      business = appointment.business
      raise ArgumentError, "El cliente o la mascota no pertenece a este negocio." unless customer.business_id == business.id && pet.business_id == business.id && pet.customer_profile_id == customer.id

      business.with_lock do
        appointment.reload
        return appointment if appointment.customer_profile_id == customer.id && appointment.pet_id == pet.id

        previous = { customer_profile_id: appointment.customer_profile_id, pet_id: appointment.pet_id }
        appointment.update!(customer_profile: customer, pet: pet)
        appointment.booking_notes.update_all(customer_profile_id: customer.id)
        appointment.booking_attachments.update_all(customer_profile_id: customer.id)
        business.customer_reminders.where(appointment: appointment).update_all(customer_profile_id: customer.id)
        business.provider_events.create!(
          user: actor,
          event_type: "appointment_customer_linked",
          title: "Cliente y mascota del turno corregidos",
          body: "Se actualizó la asociación del turno sin modificar sus datos de contacto.",
          metadata: previous.merge(appointment_id: appointment.id, new_customer_profile_id: customer.id, new_pet_id: pet.id)
        )
      end
      appointment
    end
  end
end
