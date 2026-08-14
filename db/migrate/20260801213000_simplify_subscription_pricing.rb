class SimplifySubscriptionPricing < ActiveRecord::Migration[8.0]
  FIXED_MONTHLY_AMOUNT_CENTS = 2_500_000
  SUBSCRIPTION_NAME = "Suscripción HolaTurno"
  LEGACY_PLAN_NAME = "Plan HolaTurno"

  def up
    change_column_default :subscriptions, :plan_name, from: LEGACY_PLAN_NAME, to: SUBSCRIPTION_NAME

    execute <<~SQL.squish
      UPDATE subscriptions
      SET plan_name = '#{SUBSCRIPTION_NAME}', amount_cents = #{FIXED_MONTHLY_AMOUNT_CENTS}
      WHERE plan_name = '#{LEGACY_PLAN_NAME}' OR amount_cents IS NULL OR amount_cents <> #{FIXED_MONTHLY_AMOUNT_CENTS}
    SQL

    execute <<~SQL.squish
      UPDATE subscription_invoices
      SET amount_cents = #{FIXED_MONTHLY_AMOUNT_CENTS}
      WHERE status IN ('open', 'pending_review', 'rejected', 'overdue')
    SQL

    remove_column :subscriptions, :included_professionals_count, :integer if column_exists?(:subscriptions, :included_professionals_count)
    remove_column :subscriptions, :extra_professional_amount_cents, :integer if column_exists?(:subscriptions, :extra_professional_amount_cents)
  end

  def down
    add_column :subscriptions, :included_professionals_count, :integer, null: false, default: 3 unless column_exists?(:subscriptions, :included_professionals_count)
    add_column :subscriptions, :extra_professional_amount_cents, :integer, null: false, default: 500_000 unless column_exists?(:subscriptions, :extra_professional_amount_cents)
    change_column_default :subscriptions, :plan_name, from: SUBSCRIPTION_NAME, to: LEGACY_PLAN_NAME

    execute <<~SQL.squish
      UPDATE subscriptions
      SET plan_name = '#{LEGACY_PLAN_NAME}'
      WHERE plan_name = '#{SUBSCRIPTION_NAME}'
    SQL
  end
end
