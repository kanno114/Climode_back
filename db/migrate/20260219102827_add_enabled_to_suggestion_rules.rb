class AddEnabledToSuggestionRules < ActiveRecord::Migration[7.2]
  def change
    add_column :suggestion_rules, :enabled, :boolean, default: true, null: false
  end
end
