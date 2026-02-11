# frozen_string_literal: true

class DropTriggers < ActiveRecord::Migration[7.2]
  def change
    drop_table :triggers
  end
end
