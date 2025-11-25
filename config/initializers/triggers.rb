Rails.application.config.after_initialize do
  begin
    if ActiveRecord::Base.connection.data_source_exists?(:triggers)
      Triggers::PresetLoader.call
      # トリガー同期後にDB接続を明示的に切断
      # これにより、db:dropなどのデータベース破壊的操作が正常に実行できる
      ActiveRecord::Base.connection_pool.disconnect!
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid => e
    Rails.logger.info("[Triggers::Initializer] skipped: #{e.class}: #{e.message}")
  end
end
