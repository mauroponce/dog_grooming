class PublishVisibleActiveServices < ActiveRecord::Migration[8.1]
  class MigrationService < ActiveRecord::Base
    self.table_name = "services"
  end

  def up
    MigrationService
      .where(public_visible: true, visibility_mode: "hidden", archived_at: nil)
      .update_all(active: true, visibility_mode: "public", updated_at: Time.current)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "No se puede distinguir qué servicios privados se corrigieron"
  end
end
