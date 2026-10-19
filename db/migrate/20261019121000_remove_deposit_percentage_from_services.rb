class RemoveDepositPercentageFromServices < ActiveRecord::Migration[8.1]
  def up
    remove_column :services, :deposit_percentage
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "El porcentaje por servicio fue eliminado sin preservar datos"
  end
end
