class HealthScoreCalculator
  def initialize(daily_log)
    @daily_log = daily_log
  end

  def calculate
    # 現在は適当な計算ロジック
    # 後で本格的な計算に置き換える予定
    base_score = 50

    # 睡眠時間による調整（理想的な睡眠時間: 7-8時間）
    if @daily_log.sleep_hours.present?
      if @daily_log.sleep_hours >= 7 && @daily_log.sleep_hours <= 8
        base_score += 20
      elsif @daily_log.sleep_hours >= 6 && @daily_log.sleep_hours <= 9
        base_score += 10
      elsif @daily_log.sleep_hours < 5 || @daily_log.sleep_hours > 10
        base_score -= 20
      end
    end

    # 気分による調整
    if @daily_log.mood.present?
      base_score += @daily_log.mood * 5
    end

    # 疲労度による調整
    if @daily_log.fatigue.present?
      base_score -= @daily_log.fatigue * 3
    end

    # 症状による調整
    symptom_penalty = @daily_log.symptoms.count * 5
    base_score -= symptom_penalty

    # スコアを0-100の範囲に制限
    [0, [100, base_score].min].max
  end
end
