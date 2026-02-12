class Api::V1::SuggestionsController < ApplicationController
  include Authenticatable

  def index
    begin
      date = params[:date] ? Date.parse(params[:date]) : Date.current
      daily_log = DailyLog.find_by!(user_id: current_user.id, date: date)
      suggestions = Suggestion::SuggestionEngine.call(user: current_user, date: date, daily_log: daily_log)
      Suggestion::SuggestionPersistence.call(daily_log: daily_log, suggestions: suggestions)
      render json: suggestions.map { |s| serialize(s) }
    rescue ArgumentError => e
      # 日付のパースエラー
      render json: { error: "無効な日付形式です" }, status: :bad_request
    rescue ActiveRecord::RecordNotFound => e
      # DailyLogが見つからない場合
      render json: { error: "指定された日付のログが見つかりません" }, status: :not_found
    rescue => e
      Rails.logger.error("[Suggestions] Error: #{e.class} #{e.message}")
      render json: { error: "提案の取得に失敗しました" }, status: :internal_server_error
    end
  end

  private


  def serialize(s)
    {
      key: s.key,
      title: s.title,
      message: s.message,
      tags: s.tags,
      severity: s.severity,
      triggers: s.triggers,
      category: s.category,
      level: s.level,
      reason_text: s.reason_text,
      evidence_text: s.evidence_text
    }
  end
end
