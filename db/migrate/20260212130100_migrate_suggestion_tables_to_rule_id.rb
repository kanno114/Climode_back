# frozen_string_literal: true

class MigrateSuggestionTablesToRuleId < ActiveRecord::Migration[7.2]
  def up
    # 1. daily_log_suggestions: suggestion_key → rule_id
    add_column :daily_log_suggestions, :rule_id, :bigint
    migrate_daily_log_suggestions
    remove_index :daily_log_suggestions, name: "index_daily_log_suggestions_on_daily_log_and_suggestion_key"
    remove_column :daily_log_suggestions, :suggestion_key, :string
    remove_column :daily_log_suggestions, :title, :string
    remove_column :daily_log_suggestions, :message, :text
    remove_column :daily_log_suggestions, :tags, :jsonb
    remove_column :daily_log_suggestions, :severity, :integer
    remove_column :daily_log_suggestions, :category, :string
    remove_column :daily_log_suggestions, :level, :string
    change_column_null :daily_log_suggestions, :rule_id, false
    add_foreign_key :daily_log_suggestions, :suggestion_rules, column: :rule_id
    add_index :daily_log_suggestions, [ :daily_log_id, :rule_id ], unique: true, name: "index_daily_log_suggestions_on_daily_log_and_rule"

    # 2. suggestion_snapshots: rule_key → rule_id
    add_column :suggestion_snapshots, :rule_id, :bigint
    migrate_suggestion_snapshots
    remove_index :suggestion_snapshots, name: "index_suggestion_snapshots_on_date_pref_rule"
    remove_index :suggestion_snapshots, name: "index_suggestion_snapshots_on_tags", if_exists: true
    remove_column :suggestion_snapshots, :rule_key, :string
    remove_column :suggestion_snapshots, :title, :string
    remove_column :suggestion_snapshots, :message, :text
    remove_column :suggestion_snapshots, :tags, :jsonb
    remove_column :suggestion_snapshots, :severity, :integer
    remove_column :suggestion_snapshots, :category, :string
    remove_column :suggestion_snapshots, :level, :string
    change_column_null :suggestion_snapshots, :rule_id, false
    add_foreign_key :suggestion_snapshots, :suggestion_rules, column: :rule_id
    add_index :suggestion_snapshots, [ :date, :prefecture_id, :rule_id ], unique: true, name: "index_suggestion_snapshots_on_date_pref_rule"

    # 3. suggestion_feedbacks: suggestion_key → rule_id
    add_column :suggestion_feedbacks, :rule_id, :bigint
    migrate_suggestion_feedbacks
    remove_index :suggestion_feedbacks, name: "index_suggestion_feedbacks_on_daily_log_id_and_suggestion_key"
    remove_column :suggestion_feedbacks, :suggestion_key, :string
    change_column_null :suggestion_feedbacks, :rule_id, false
    add_foreign_key :suggestion_feedbacks, :suggestion_rules, column: :rule_id
    add_index :suggestion_feedbacks, [ :daily_log_id, :rule_id ], unique: true, name: "index_suggestion_feedbacks_on_daily_log_and_rule"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot reverse rule_id migration: suggestion_key data was dropped"
  end

  private

  def migrate_daily_log_suggestions
    rule_by_key = SuggestionRule.all.to_h { |r| [ r.key, r.id ] }
    DailyLogSuggestion.reset_column_information
    DailyLogSuggestion.find_each do |rec|
      key = rec.read_attribute(:suggestion_key)
      rule_id = rule_by_key[key]
      if rule_id
        rec.update_column(:rule_id, rule_id)
      else
        rec.destroy! # 存在しないルールを参照するレコードは削除
      end
    end
  end

  def migrate_suggestion_snapshots
    rule_by_key = SuggestionRule.all.to_h { |r| [ r.key, r.id ] }
    SuggestionSnapshot.reset_column_information
    SuggestionSnapshot.find_each do |rec|
      key = rec.read_attribute(:rule_key)
      rule_id = rule_by_key[key]
      if rule_id
        rec.update_column(:rule_id, rule_id)
      else
        rec.destroy!
      end
    end
  end

  def migrate_suggestion_feedbacks
    rule_by_key = SuggestionRule.all.to_h { |r| [ r.key, r.id ] }
    SuggestionFeedback.reset_column_information
    SuggestionFeedback.find_each do |rec|
      key = rec.read_attribute(:suggestion_key)
      rule_id = rule_by_key[key]
      if rule_id
        rec.update_column(:rule_id, rule_id)
      else
        rec.destroy!
      end
    end
  end
end
