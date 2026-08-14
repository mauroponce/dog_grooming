class RemoveReviewRelatedRecords < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM sales_opportunities WHERE opportunity_type = 'review_request'"
    execute "DELETE FROM sales_campaigns WHERE objective = 'request_reviews'"
    execute "DELETE FROM promotions WHERE promotion_type = 'review_boost'"
    execute "DELETE FROM whatsapp_templates WHERE key = 'review_request'"
    execute "DELETE FROM content_templates WHERE key = 'review_boost'"
  end

  def down
    # Deleted review records cannot be restored safely.
  end
end
