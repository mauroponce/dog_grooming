class AddProfileFieldsToEmployeeMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :employee_memberships, :first_name, :string
    add_column :employee_memberships, :last_name, :string
    add_column :employee_memberships, :additional_phone, :string
    add_column :employee_memberships, :calendar_color, :string

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE employee_memberships
          SET
            first_name = NULLIF(split_part(name, ' ', 1), ''),
            last_name = NULLIF(btrim(regexp_replace(name, '^\\S+\\s*', '')), ''),
            calendar_color = COALESCE(calendar_color, '#3b82f6')
        SQL
      end
    end
  end
end
