module Score
  class ScoreCalculatorV1
    # === 重み（合計は 1.0 想定） ===
    W = {
      top_body: 0.7, top_env: 0.3,
      body: { sleep: 0.6, mood: 0.4 },
      env:  { press: 0.40, humid: 0.25, temp: 0.20, pm25: 0.10, pollen: 0.05 }
    }.freeze

    def initialize(daily_log)
      @log = daily_log
      @weather_snapshot = WeatherSnapshot.find_by(
        prefecture: daily_log.prefecture,
        date: daily_log.date
      )
    end

    # スコア算出（0..100）
    # persist: true で daily_log.score を更新
    def call(persist: true)
      norms = normalize(@log)

      b = combine_body(norms)
      e = combine_env(norms)
      m = modifiers(@log)

      # 欠損再配分（有効重みで平均化）
      b_val = redistribute_if_missing(b[:val], b[:weight_sum])
      e_val = redistribute_if_missing(e[:val], e[:weight_sum])

      raw   = 100.0 * (W[:top_body] * b_val + W[:top_env] * e_val) + m
      score = raw.round.clamp(0, 100)

      @log.update!(score: score) if persist

      { score: score, details: { norms: norms, modifiers: m } }
    end

    private

    # === 正規化（0..1, 1=良い） ===
    def normalize(log)
      metrics = @weather_snapshot&.metrics || {}

      {
        sleep:  sleep_norm(log.sleep_hours),               # U字（7–8h ≈ 最高）
        mood:   linear_norm(log.mood, -5, 5),              # -5..5 → 0..1
        press:  pressure_norm(metrics["pressure_hpa"]),            # 絶対気圧（線形：高いほど良い）
        humid:  metrics["humidity_pct"] ? comfort_humid(metrics["humidity_pct"]) : nil,       # 40–60% で最大
        temp:   metrics["temperature_c"] ? comfort_temp(metrics["temperature_c"]) : nil,       # 20–25℃ で最大
        pm25:   nil,         # 未実装
        pollen: nil # 未実装
      }.compact
    end

    # --- 正規化ヘルパ ---
    # 線形：min..max → 0..1
    def linear_norm(x, min, max)
      return nil if x.nil?
      v = (x.to_f - min) / (max - min).to_f
      [ [ v, 0.0 ].max, 1.0 ].min
    end

    # 上限 cap でクリップ。inverse: true で 1-v（小さいほど良い）
    def cap_norm(x, cap:, inverse:)
      return nil if x.nil?
      v = [ [ x.to_f / cap.to_f, 0.0 ].max, 1.0 ].min
      inverse ? (1.0 - v) : v
    end

    # 0..max を 0..1 に線形。inverse: true で 1-v
    def step_norm(x, max:, inverse:)
      return nil if x.nil?
      v = [ [ x.to_f / max.to_f, 0.0 ].max, 1.0 ].min
      inverse ? (1.0 - v) : v
    end

    # 絶対気圧（高いほど良い）: 985..1025hPa を仮の運用レンジに
    # 985 → 0.0（悪） / 1025 → 1.0（良）
    def pressure_norm(p)
      return nil if p.nil?
      linear_norm(p.to_f, 985.0, 1025.0)
    end

    # 7–8h で最大、それ以外は落ちる（U字）
    def sleep_norm(h)
      return nil if h.nil?
      h = h.to_f
      return 0.1 if h < 4
      return 0.6 if h > 12
      if h < 6
        0.1 + (h - 4) / 2 * 0.6      # 4→6h: 0.1→0.7
      elsif h <= 8
        0.7 + (h - 6) / 2 * 0.3      # 6→8h: 0.7→1.0
      elsif h <= 9.5
        1.0 - (h - 8) / 1.5 * 0.2    # 8→9.5h: 1.0→0.8
      else
        0.7
      end
    end

    # 湿度の快適度（1=快適）
    # 40–60% を最大、それ以外は中心 50% からの距離で減点
    def comfort_humid(h)
      return nil if h.nil?
      if (40..60).cover?(h)
        1.0
      else
        pen = [ [ (h.to_f - 50.0).abs / 40.0, 0.0 ].max, 1.0 ].min
        1.0 - pen
      end
    end

    # 気温の快適度（1=快適）
    # 20–25℃ を最大、それ以外は中心 22.5℃ からの距離で減点
    def comfort_temp(t)
      return nil if t.nil?
      if (20..25).cover?(t)
        1.0
      else
        pen = [ [ (t.to_f - 22.5).abs / 12.5, 0.0 ].max, 1.0 ].min
        1.0 - pen
      end
    end

    # === 合成（欠損は重み再配分） ===
    def combine_body(n)
      parts = []
      wsum  = 0.0
      if n[:sleep]
        parts << W[:body][:sleep] * n[:sleep]; wsum += W[:body][:sleep]
      end
      if n[:mood]
        parts << W[:body][:mood] * n[:mood];   wsum += W[:body][:mood]
      end
      { val: parts.sum, weight_sum: wsum }
    end

    def combine_env(n)
      items = {
        press:  W[:env][:press],
        humid:  W[:env][:humid],
        temp:   W[:env][:temp],
        pm25:   W[:env][:pm25],
        pollen: W[:env][:pollen]
      }
      val = 0.0
      wsum = 0.0
      items.each do |k, w|
        next unless n[k]
        val  += w * n[k]
        wsum += w
      end
      { val: val, weight_sum: wsum }
    end

    # 有効重みが 0 → 0.5（中立）、それ以外は重み平均を返す
    def redistribute_if_missing(weighted_val, weight_sum)
      return 0.5 if weight_sum.zero? # 全欠損→中立値
      (weighted_val / weight_sum).clamp(0.0, 1.0)
    end

    # === 補正（離散ペナルティ/ボーナス） ===
    # ※ 二重カウント回避のため「睡眠不足の減点」は削除
    def modifiers(log)
      m = 0
      metrics = @weather_snapshot&.metrics || {}

      # 低気圧の影響（例：1007hPa 以下で減点）
      pressure_hpa = metrics["pressure_hpa"]
      m -= 8 if pressure_hpa && pressure_hpa <= 1007

      m
    end
  end
end
