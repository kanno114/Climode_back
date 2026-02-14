class Api::V1::DailyLogsController < ApplicationController
  include Authenticatable
  before_action :set_daily_log, only: [ :show, :update, :destroy, :update_self_score ]

  # GET /api/v1/daily_logs
  def index
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 10).to_i
    offset = (page - 1) * per_page

    @daily_logs = current_user.daily_logs
                              .includes(:prefecture)
                              .order(date: :desc)
                              .offset(offset)
                              .limit(per_page)

    total_count = current_user.daily_logs.count
    total_pages = (total_count.to_f / per_page).ceil

    render json: {
      daily_logs: @daily_logs.as_json(include: [ :prefecture ]),
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
    daily_log_json = @daily_log.as_json(
      include: [
        :prefecture,
        { suggestion_feedbacks: { methods: [ :suggestion_key ] } },
        { daily_log_suggestions: { include: :suggestion_rule } }
      ]
    )

    # フロントで扱いやすい形式（key, title, message, tags, severity, category, level, triggers, reason_text, evidence_text）に変換
    daily_log_json["daily_log_suggestions"] = @daily_log.daily_log_suggestions
      .includes(:suggestion_rule)
      .order(:position, :id)
      .map do |s|
        rule = s.suggestion_rule
        {
          key: rule.key,
          title: rule.title,
          message: rule.message.to_s,
          tags: Array(rule.tags),
          severity: rule.severity,
          triggers: {},
          category: rule.category,
          level: rule.level,
          reason_text: rule.reason_text,
          evidence_text: rule.evidence_text
        }
      end

    render json: daily_log_json
  end

  # GET /api/v1/daily_logs/date/:date
  def show_by_date
    @daily_log = current_user.daily_logs
                             .includes(:prefecture, { suggestion_feedbacks: :suggestion_rule })
                             .find_by(date: params[:date])

    if @daily_log
      render json: @daily_log.as_json(
        include: [ :prefecture, { suggestion_feedbacks: { methods: [ :suggestion_key ] } } ]
      )
    else
      render json: { error: "指定された日付のデイリーログが見つかりません" },
             status: :not_found
    end
  end

  # GET /api/v1/daily_logs/date_range_30days
  def by_date_range_30days
    # 過去1ヶ月のデータを取得（今日から30日前まで）
    end_date = Date.current
    start_date = end_date - 30.days

    @daily_logs = current_user.daily_logs
                              .includes(:prefecture)
                              .where(date: start_date..end_date)
                              .order(date: :desc)

    render json: @daily_logs.as_json(include: [ :prefecture ])
  end

  # GET /api/v1/daily_logs/by_month?year=2024&month=11
  def by_month
    year = params[:year]&.to_i || Date.current.year
    month = params[:month]&.to_i || Date.current.month

    # 月の範囲を計算
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    @daily_logs = current_user.daily_logs
                              .includes(:prefecture)
                              .where(date: start_date..end_date)
                              .order(date: :desc)

    render json: @daily_logs.as_json(include: [ :prefecture ])
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
      note: daily_log_data[:note] || daily_log_data[:memo] || daily_log_data[:notes] || ""
    )


    if @daily_log.save
      render json: @daily_log.as_json(include: [ :prefecture ]),
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
      note: daily_log_data[:note] || daily_log_data[:memo] || daily_log_data[:notes] || ""
    )

    if @daily_log.save
      render json: @daily_log.as_json(include: [ :prefecture ])
    else
      render json: { errors: @daily_log.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/daily_logs/:id/self_score
  def update_self_score
    self_score_value = params[:self_score]&.to_i
    unless self_score_value.nil? || (1..3).cover?(self_score_value)
      return render json: { errors: [ "self_scoreは1〜3の範囲で指定してください" ] },
                    status: :unprocessable_entity
    end

    if @daily_log.update(self_score: self_score_value)
      render json: @daily_log.as_json(include: [ :prefecture ])
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

  # POST /api/v1/daily_logs/morning
  def morning
    today = Date.current

    # 当日のDailyLogを検索
    @daily_log = current_user.daily_logs.find_by(date: today)

    # prefecture_idを決定（既存のDailyLogから取得、またはユーザーのデフォルト都道府県）
    prefecture = if @daily_log&.prefecture
      @daily_log.prefecture
    elsif current_user.prefecture
      current_user.prefecture
    else
      # デフォルト都道府県がない場合は東京を取得
      Prefecture.find_by(code: "13") || Prefecture.first
    end

    # パラメータから値を取得
    sleep_hours = params[:sleep_hours]&.to_f
    mood = params[:mood]&.to_i
    fatigue = params[:fatigue]&.to_i

    if @daily_log
      # 既存のDailyLogを更新
      @daily_log.assign_attributes(
        sleep_hours: sleep_hours,
        mood: mood,
        fatigue: fatigue
      )
    else
      # 新規作成
      @daily_log = current_user.daily_logs.build(
        date: today,
        prefecture: prefecture,
        sleep_hours: sleep_hours,
        mood: mood,
        fatigue: fatigue
      )
    end

    if @daily_log.save
      render json: { status: "ok", next: "/dashboard" }, status: :ok
    else
      render json: { errors: @daily_log.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  # POST /api/v1/daily_logs/evening
  def evening
    today = Date.current

    Rails.logger.info "Evening reflection request received for user #{current_user.id} on #{today}"

    # 当日のDailyLogを取得または作成
    @daily_log = current_user.daily_logs.find_by(date: today)

    # prefecture_idを決定（既存のDailyLogから取得、またはユーザーのデフォルト都道府県）
    prefecture = if @daily_log&.prefecture
      @daily_log.prefecture
    elsif current_user.prefecture
      current_user.prefecture
    else
      # デフォルト都道府県がない場合は東京を取得
      Prefecture.find_by(code: "13") || Prefecture.first
    end

    # パラメータから値を取得
    note = params[:note]
    self_score = params[:self_score]&.to_i
    suggestion_feedbacks_params = if params[:suggestion_feedbacks].is_a?(String)
      begin
        JSON.parse(params[:suggestion_feedbacks])
      rescue JSON::ParserError => e
        Rails.logger.warn "[DailyLogs#evening] JSON parse error: #{e.message}"
        []
      end
    else
      params[:suggestion_feedbacks] || []
    end

    Rails.logger.info "Evening reflection params: note=#{note.present? ? 'present' : 'empty'}, self_score=#{self_score.present? ? self_score : 'nil'}, suggestion_feedbacks_count=#{suggestion_feedbacks_params.size}"

    # DailyLogの作成または更新
    if @daily_log
      @daily_log.assign_attributes(
        note: note,
        self_score: self_score
      )
    else
      @daily_log = current_user.daily_logs.build(
        date: today,
        prefecture: prefecture,
        note: note,
        self_score: self_score
      )
    end

    # トランザクション内で保存とフィードバック処理
    save_success = false

    ActiveRecord::Base.transaction do
      unless @daily_log.save
        raise ActiveRecord::Rollback
      end

      # 提案フィードバックの保存
      @daily_log.suggestion_feedbacks.destroy_all
      if suggestion_feedbacks_params.present?
        suggestion_feedbacks_params.each do |feedback_params|
          key = feedback_params[:key] || feedback_params["key"] || feedback_params[:suggestion_key] || feedback_params["suggestion_key"]
          helpfulness = feedback_params[:helpfulness] || feedback_params["helpfulness"]

          Rails.logger.info "Processing suggestion feedback: key=#{key}, helpfulness=#{helpfulness} (#{helpfulness.class})"

          # helpfulnessのバリデーション（booleanであることを確認）
          unless [ true, false ].include?(helpfulness)
            Rails.logger.warn "Invalid helpfulness value: #{helpfulness}, skipping"
            next
          end

          rule = SuggestionRule.find_by(key: key)
          next unless rule

          @daily_log.suggestion_feedbacks.create!(
            suggestion_rule: rule,
            helpfulness: helpfulness
          )
        end
      end

      save_success = true
    end

    if save_success
      Rails.logger.info "Evening reflection saved successfully for daily_log #{@daily_log.id}"
      render json: { status: "ok", next: "/dashboard" }, status: :ok
    else
      render json: { errors: @daily_log.errors.full_messages },
             status: :unprocessable_entity
    end
  end

  private

  def set_daily_log
    @daily_log = current_user.daily_logs
                            .includes(:prefecture, { suggestion_feedbacks: :suggestion_rule }, { daily_log_suggestions: :suggestion_rule })
                            .find(params[:id])
  end

  def daily_log_params
    params.require(:daily_log).permit(
      :date,
      :prefecture_id,
      :sleep_hours,
      :mood,
      :self_score,
      :note
    )
  end
end
