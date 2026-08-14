class UpdateLaunchPlanMonthlyAmountTo25000 < ActiveRecord::Migration[8.0]
  NEW_BASE_AMOUNT_CENTS = 2_500_000
  OLD_BASE_AMOUNT_CENTS = 2_000_000
  INCLUDED_PROFESSIONALS_COUNT = 3
  EXTRA_PROFESSIONAL_AMOUNT_CENTS = 500_000

  def up
    change_column_default :subscriptions, :amount_cents, from: OLD_BASE_AMOUNT_CENTS, to: NEW_BASE_AMOUNT_CENTS

    execute <<~SQL.squish
      UPDATE subscriptions
      SET amount_cents = #{NEW_BASE_AMOUNT_CENTS},
          updated_at = CURRENT_TIMESTAMP
      WHERE plan_name = 'Plan HolaTurno'
        AND amount_cents = #{OLD_BASE_AMOUNT_CENTS}
    SQL

    execute <<~SQL.squish
      WITH bookable_professionals AS (
        SELECT business_id, COUNT(*) AS active_count
        FROM employee_memberships
        WHERE status = 'active'
          AND archived_at IS NULL
          AND can_receive_appointments = TRUE
        GROUP BY business_id
      )
      UPDATE subscription_invoices
      SET amount_cents = #{NEW_BASE_AMOUNT_CENTS}
          + GREATEST(COALESCE(bookable_professionals.active_count, 0) - #{INCLUDED_PROFESSIONALS_COUNT}, 0)
          * #{EXTRA_PROFESSIONAL_AMOUNT_CENTS},
          updated_at = CURRENT_TIMESTAMP
      FROM subscriptions
      LEFT JOIN bookable_professionals ON bookable_professionals.business_id = subscriptions.business_id
      WHERE subscription_invoices.subscription_id = subscriptions.id
        AND subscriptions.plan_name = 'Plan HolaTurno'
        AND subscription_invoices.status IN ('open', 'overdue', 'rejected')
    SQL
  end

  def down
    change_column_default :subscriptions, :amount_cents, from: NEW_BASE_AMOUNT_CENTS, to: OLD_BASE_AMOUNT_CENTS

    execute <<~SQL.squish
      UPDATE subscriptions
      SET amount_cents = #{OLD_BASE_AMOUNT_CENTS},
          updated_at = CURRENT_TIMESTAMP
      WHERE plan_name = 'Plan HolaTurno'
        AND amount_cents = #{NEW_BASE_AMOUNT_CENTS}
    SQL
  end
end
