class AddEmailConfirmationToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :email_confirmed, :boolean, default: false, null: false
    add_column :users, :confirmation_token_digest, :string
    add_column :users, :confirmation_sent_at, :datetime
    add_index :users, :confirmation_token_digest, unique: true

    # 既存ユーザーは確認済みとして扱う
    reversible do |dir|
      dir.up do
        execute "UPDATE users SET email_confirmed = true"
      end
    end
  end
end
