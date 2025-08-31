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
    @daily_log = current_user.daily_logs.build(daily_log_params)
    
    # 体調スコアを計算
    @daily_log.score = HealthScoreCalculator.new(@daily_log).calculate

    if @daily_log.save
      # 天気データを作成（ダミーデータ）
      create_weather_observation
      
      render json: @daily_log.as_json(include: [:prefecture, :weather_observation, :symptoms]), 
             status: :created
    else
      render json: { errors: @daily_log.errors.full_messages }, 
             status: :unprocessable_entity
    end
  end

  # PUT /api/v1/daily_logs/:id
  def update
    if @daily_log.update(daily_log_params)
      # 体調スコアを再計算
      @daily_log.update(score: HealthScoreCalculator.new(@daily_log).calculate)
      
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
      :fatigue, 
      :self_score, 
      :memo,
      symptom_ids: []
    )
  end

  def create_weather_observation
    prefecture = @daily_log.prefecture
    weather_data = WeatherDataService.new(prefecture, @daily_log.date).fetch_weather_data
    
    @daily_log.create_weather_observation!(
      temperature_c: weather_data[:temperature_c],
      humidity_pct: weather_data[:humidity_pct],
      pressure_hpa: weather_data[:pressure_hpa],
      observed_at: weather_data[:observed_at],
      snapshot: weather_data[:snapshot]
    )
  end

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
