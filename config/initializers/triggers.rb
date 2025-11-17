Rails.application.config.after_initialize do
  begin
    if ActiveRecord::Base.connection.data_source_exists?(:triggers)
      Triggers::PresetLoader.call
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid => e
    Rails.logger.info("[Triggers::Initializer] skipped: #{e.class}: #{e.message}")
  end
end

