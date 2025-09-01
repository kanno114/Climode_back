class Api::V1::DailyLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_daily_log, only: [:show, :update, :destroy]

  # GET /api/v1/daily_logs
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    offset = (page - 1) * per_page
    
    @daily_logs = current_user.daily_logs
                              .includes(:prefecture, :weather_observation, :symptoms)
                              .order(date: :desc)
                              .offset(offset)
                              .limit(per_page)
    
    total_count = current_user.daily_logs.count
    total_pages = (total_count.to_f / per_page).ceil

    render json: {
      daily_logs: @daily_logs.as_json(include: [:prefecture, :weather_observation, :symptoms]),
      pagination: {
        current_page: page,
        total_pages: total_pages,
        total_count: total_count,
        per_page: per_page
      }
    }
  end

  # GET /api/v1/daily_logs/:id
  def show
    render json: @daily_log.as_json(include: [:prefecture, :weather_observation, :symptoms])
  end

  # POST /api/v1/daily_logs
  def create
    # フロントエンドからのデータを処理
    daily_log_data = params[:daily_log]
    
    # 都道府県を取得
    prefecture = Prefecture.find(daily_log_data[:prefecture_id])
    
    @daily_log = current_user.daily_logs.build(
      date: daily_log_data[:date],
      prefecture: prefecture,
      sleep_hours: daily_log_data[:sleep_hours],
      mood: daily_log_data[:mood] || daily_log_data[:mood_score]&.to_i,
      fatigue: daily_log_data[:fatigue],
      memo: daily_log_data[:memo] || daily_log_data[:notes] || ""
    )
    
    # 体調スコアを計算
    @daily_log.score = HealthScoreCalculator.new(@daily_log).calculate

    if @daily_log.save
      # 症状を関連付け
      if daily_log_data[:symptoms].present?
        symptoms = JSON.parse(daily_log_data[:symptoms])
        symptoms.each do |symptom_code|
          symptom = Symptom.find_by(code: symptom_code)
          if symptom
            @daily_log.daily_log_symptoms.create!(symptom: symptom)
          end
        end
      end
      
      # 天気データはモデルのコールバックで自動取得される
      
      render json: @daily_log.as_json(include: [:prefecture, :weather_observation, :symptoms]), 
             status: :created
    else
      render json: { errors: @daily_log.errors.full_messages }, 
             status: :unprocessable_entity
    end
  end

  # PUT /api/v1/daily_logs/:id
  def update
    # フロントエンドからのデータを処理
    daily_log_data = params[:daily_log]
    
    # 都道府県を取得
    prefecture = Prefecture.find(daily_log_data[:prefecture_id])
    
    # 既存の記録を更新
    @daily_log.assign_attributes(
      prefecture: prefecture,
      sleep_hours: daily_log_data[:sleep_hours],
      mood: daily_log_data[:mood] || daily_log_data[:mood_score]&.to_i,
      fatigue: daily_log_data[:fatigue],
      memo: daily_log_data[:memo] || daily_log_data[:notes] || ""
    )
    
    # 体調スコアを再計算
    @daily_log.score = HealthScoreCalculator.new(@daily_log).calculate

    if @daily_log.save
      # 既存の症状を削除
      @daily_log.daily_log_symptoms.destroy_all
      
      # 症状を関連付け
      if daily_log_data[:symptoms].present?
        symptoms = JSON.parse(daily_log_data[:symptoms])
        symptoms.each do |symptom_code|
          symptom = Symptom.find_by(code: symptom_code)
          if symptom
            @daily_log.daily_log_symptoms.create!(symptom: symptom)
          end
        end
      end
      
      render json: @daily_log.as_json(include: [:prefecture, :weather_observation, :symptoms])
    else
      render json: { errors: @daily_log.errors.full_messages }, 
             status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/daily_logs/:id
  def destroy
    @daily_log.destroy
    head :no_content
  end

  # GET /api/v1/daily_logs/date/:date
  def show_by_date
    @daily_log = current_user.daily_logs
                             .includes(:prefecture, :weather_observation, :symptoms)
                             .find_by(date: params[:date])
    
    if @daily_log
      render json: @daily_log.as_json(include: [:prefecture, :weather_observation, :symptoms])
    else
      render json: { error: "Daily log not found for date: #{params[:date]}" }, 
             status: :not_found
    end
  end

  private

  def set_daily_log
    @daily_log = current_user.daily_logs.find(params[:id])
  end

  def daily_log_params
    params.require(:daily_log).permit(
      :date, 
      :prefecture_id, 
      :sleep_hours, 
      :mood, 
      :self_score, 
      :memo,
      symptom_ids: []
    )
  end

  # 天気データ作成メソッドは削除（モデルのコールバックに移行）

  def authenticate_user!
    # 認証ロジックは既存の実装に依存
    # 現在は仮実装
    @current_user = User.find_by(id: request.headers['User-Id'])
    
    unless @current_user
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end
end
