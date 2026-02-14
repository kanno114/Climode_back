class SuggestionFeedback < ApplicationRecord
  belongs_to :daily_log
  belongs_to :suggestion_rule, foreign_key: :rule_id

  validates :helpfulness, inclusion: { in: [ true, false ] }
  validates :rule_id, uniqueness: { scope: :daily_log_id }

  # API レスポンスの backward compatibility（フロントが suggestion_key を期待）
  def suggestion_key
    suggestion_rule&.key
  end
end
