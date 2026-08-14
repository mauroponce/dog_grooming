class RemovePublicDescriptionFromServices < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE services
      SET description = public_description
      WHERE (description IS NULL OR btrim(description) = '')
        AND public_description IS NOT NULL
        AND btrim(public_description) <> ''
    SQL

    remove_column :services, :public_description, :text
  end

  def down
    add_column :services, :public_description, :text
  end
end
