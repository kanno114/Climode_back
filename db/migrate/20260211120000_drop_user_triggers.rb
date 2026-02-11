# frozen_string_literal: true

class DropUserTriggers < ActiveRecord::Migration[7.2]
  def change
    drop_table :user_triggers
  end
end
