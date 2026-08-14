class AllowCustomersWithoutPhone < ActiveRecord::Migration[8.0]
  class MigrationCustomerProfile < ActiveRecord::Base
    self.table_name = "customer_profiles"
  end

  class MigrationAppointment < ActiveRecord::Base
    self.table_name = "appointments"
  end

  def up
    change_column_null :customer_profiles, :phone, true
    change_column_null :customer_profiles, :normalized_phone, true

    MigrationAppointment
      .where(customer_profile_id: nil, customer_phone: [ nil, "" ])
      .where.not(customer_name: [ nil, "", "Sin cita" ])
      .distinct
      .pluck(:business_id, :customer_name)
      .each do |business_id, customer_name|
        profile = MigrationCustomerProfile.create!(
          business_id: business_id,
          name: customer_name,
          marketing_consent: false,
          created_at: Time.current,
          updated_at: Time.current
        )
        MigrationAppointment
          .where(business_id: business_id, customer_profile_id: nil, customer_name: customer_name, customer_phone: [ nil, "" ])
          .update_all(customer_profile_id: profile.id, updated_at: Time.current)
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Los clientes sin teléfono pueden tener turnos asociados"
  end
end
