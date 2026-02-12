class MorningSuggestionJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    Rails.logger.info "Starting morning suggestion snapshot job for #{date}..."

    update_weather_snapshots(date)
    build_suggestion_snapshots(date)

    Rails.logger.info "Morning suggestion snapshot job completed."
  end

  private

  def update_weather_snapshots(date)
    Rails.logger.info "Updating weather snapshots for all prefectures..."
    Weather::WeatherSnapshotService.update_all_prefectures(date)
  end

  def build_suggestion_snapshots(date)
    Rails.logger.info "Building SuggestionSnapshot records for all prefectures..."

    env_rules = ::Suggestion::RuleRegistry.all.select { |r| r.category == "env" }

    # 対象日のスナップショットを一旦クリア
    SuggestionSnapshot.where(date: date).delete_all

    Prefecture.find_each do |prefecture|
      snapshot = WeatherSnapshot.find_by(prefecture: prefecture, date: date)
      metrics = snapshot&.metrics || {}
      next if metrics.blank?

      ctx = {
        "temperature_c"     => (metrics["temperature_c"] || 0).to_f,
        "min_temperature_c" => (metrics["min_temperature_c"] || 0).to_f,
        "humidity_pct"      => (metrics["humidity_pct"] || 0).to_f,
        "pressure_hpa"      => (metrics["pressure_hpa"] || 0).to_f,
        "max_pressure_drop_1h_awake"   => (metrics["max_pressure_drop_1h_awake"] || 0).to_f,
        "low_pressure_duration_1003h"  => (metrics["low_pressure_duration_1003h"] || 0).to_f,
        "low_pressure_duration_1007h"  => (metrics["low_pressure_duration_1007h"] || 0).to_f,
        "pressure_range_3h_awake"      => (metrics["pressure_range_3h_awake"] || 0).to_f,
        "pressure_jitter_3h_awake"     => (metrics["pressure_jitter_3h_awake"] || 0).to_f
      }

      suggestions = ::Suggestion::RuleEngine.call(
        rules: env_rules,
        context: ctx,
        # 都道府県スナップショットでは情報を落とさないよう、件数・タグ制限は緩めにする
        limit: 20,
        tag_diversity: false
      )

      next if suggestions.empty?

      records = suggestions.map do |s|
        {
          date: date,
          prefecture_id: prefecture.id,
          rule_key: s.key,
          title: s.title,
          message: s.message,
          tags: s.tags,
          severity: s.severity,
          category: s.category,
          level: s.level,
          metadata: ctx.dup,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      SuggestionSnapshot.insert_all!(records)
    rescue => e
      Rails.logger.error "Failed to build SuggestionSnapshot for prefecture #{prefecture.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
