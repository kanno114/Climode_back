class Api::V1::SuggestionsController < ApplicationController
  before_action :authenticate_user!

  def index
    begin
      suggestions = Suggestion::SuggestionEngine.call(user: @current_user)
      render json: suggestions.map { |s| serialize(s) }
    rescue ActiveRecord::RecordNotFound => e
      # DailyLogが見つからない場合
      render json: { error: "指定された日付のログが見つかりません" }, status: :not_found
    rescue => e
      Rails.logger.error("[Suggestions] Error: #{e.class} #{e.message}")
      render json: { error: "提案の取得に失敗しました" }, status: :internal_server_error
    end
  end

  private

  def authenticate_user!
    # 認証ロジックは既存の実装に依存
    # 現在は仮実装
    @current_user = User.find_by(id: request.headers['User-Id'])
    
    unless @current_user
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def serialize(s)
    {
      key: s.key,
      title: s.title,
      message: s.message,
      tags: s.tags,
      severity: s.severity,
      triggers: s.triggers,
    }
  end
end
