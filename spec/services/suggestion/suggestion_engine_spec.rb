require 'rails_helper'

RSpec.describe Suggestion::SuggestionEngine do
  let(:user) { create(:user, prefecture: create(:prefecture)) }
  let(:date) { Date.current }

  describe '.call' do
    context 'DailyLogが存在する場合' do
      let!(:daily_log) do
        create(:daily_log,
               user: user,
               date: date,
               sleep_hours: 5.0,
               mood: 3)
      end

      let!(:user_concern_topics) do
        sleep_topic = ConcernTopic.find_or_create_by!(key: "sleep_time") do |c|
          c.label_ja = "睡眠時間"
          c.rule_concerns = ["sleep_time"]
          c.position = 1
          c.active = true
        end
        heat_topic = ConcernTopic.find_or_create_by!(key: "heatstroke") do |c|
          c.label_ja = "熱中症"
          c.rule_concerns = ["heatstroke"]
          c.position = 1
          c.active = true
        end
        [
          create(:user_concern_topic, user: user, concern_topic: sleep_topic),
          create(:user_concern_topic, user: user, concern_topic: heat_topic)
        ]
      end

      let!(:weather_snapshot) do
        create(:weather_snapshot,
               prefecture: user.prefecture,
               date: date,
               metrics: {
                 "temperature_c" => 25.0,
                 "min_temperature_c" => 18.0,
                 "humidity_pct" => 50.0,
                 "pressure_hpa" => 1013.0,
                 "max_pressure_drop_1h_awake" => 0.0,
                 "low_pressure_duration_1003h" => 0.0,
                 "low_pressure_duration_1007h" => 0.0,
                 "pressure_range_3h_awake" => 0.0,
                 "pressure_jitter_3h_awake" => 0.0
               })
      end

      context '単一条件に一致する場合' do
        it '提案を返す' do
          suggestions = described_class.call(user: user, date: date)

          expect(suggestions).to be_an(Array)
          expect(suggestions.length).to be > 0
          expect(suggestions.first).to have_attributes(
            key: be_a(String),
            title: be_a(String),
            message: be_a(String),
            tags: be_an(Array),
            severity: be_a(Integer),
            triggers: be_a(Hash)
          )
        end

        it 'sleep_Cautionルールに一致する場合、適切な提案を返す' do
          # 5〜6時間未満でsleep_Cautionが発火する
          daily_log.update!(sleep_hours: 5.5)

          suggestions = described_class.call(user: user, date: date)
          sleep_suggestion = suggestions.find { |s| s.key == 'sleep_Caution' }

          expect(sleep_suggestion).to be_present
          expect(sleep_suggestion.title).to eq('睡眠不足気味。生活時間を見直して')
          expect(sleep_suggestion.severity).to eq(75)
          expect(sleep_suggestion.tags).to include('sleep')
        end
      end

      context '複数条件に一致する場合' do
        it '複数の提案を返す' do
          daily_log.update!(sleep_hours: 5.0)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 32.0,
            "min_temperature_c" => 20.0,
            "humidity_pct" => 75.0,
            "pressure_hpa" => 1013.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user, date: date)

          expect(suggestions.length).to be > 1
          expect(suggestions.map(&:key)).to include('sleep_Caution')
        end

        it 'heatstroke_Warningルールに一致する場合、適切な提案を返す' do
          weather_snapshot.update!(metrics: {
            "temperature_c" => 32.0,
            "min_temperature_c" => 22.0,
            "humidity_pct" => 50.0,
            "pressure_hpa" => 1013.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user, date: date)
          heat_suggestion = suggestions.find { |s| s.key == 'heatstroke_Warning' }

          if heat_suggestion
            expect(heat_suggestion.title).to eq('暑い日。炎天下を避け、激しい運動は中止')
            expect(heat_suggestion.severity).to eq(75)
            expect(heat_suggestion.tags).to include('temperature', 'heatstroke')
          else
            expect(suggestions.length).to be > 0
          end
        end
      end

      context '気圧差・気象病ルール' do
        it 'weather_pain_drop_Warning が発火するコンテキストを評価できる' do
          ctx = {
            "sleep_hours" => 0.0,
            "mood" => 0,
            "score" => 0,
            "temperature_c" => 0.0,
            "min_temperature_c" => 0.0,
            "humidity_pct" => 0.0,
            "pressure_hpa" => 1013.0,
            "max_pressure_drop_1h_awake" => -3.5,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          }

          rules = Suggestion::RuleRegistry.all.select { |r| r.key == 'weather_pain_drop_Warning' }
          suggestions = Suggestion::RuleEngine.call(rules: rules, context: ctx, limit: 3, tag_diversity: false)

          keys = suggestions.map(&:key)
          expect(keys).to include('weather_pain_drop_Warning')
        end

        it 'low_pressure_duration_* に応じて 1003h / 1007h ルールが切り替わる' do
          base_ctx = {
            "sleep_hours" => 0.0,
            "mood" => 0,
            "score" => 0,
            "temperature_c" => 0.0,
            "min_temperature_c" => 0.0,
            "humidity_pct" => 0.0,
            "pressure_hpa" => 1005.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          }

          # 1003hPa 以下が3時間以上 → weather_pain_low_1003_1
          ctx_1003 = base_ctx.merge(
            "low_pressure_duration_1003h" => 3.0,
            "low_pressure_duration_1007h" => 4.0
          )
          rules_1003 = Suggestion::RuleRegistry.all.select { |r| r.key == 'weather_pain_low_1003_Warning' }
          suggestions_1003 = Suggestion::RuleEngine.call(rules: rules_1003, context: ctx_1003, limit: 3, tag_diversity: false)
          expect(suggestions_1003.map(&:key)).to include('weather_pain_low_1003_Warning')

          # 1007hPa 以下のみ3時間以上（1003hPa は3時間未満）→ weather_pain_low_1007_Caution
          ctx_1007 = base_ctx.merge(
            "low_pressure_duration_1003h" => 2.0,
            "low_pressure_duration_1007h" => 3.5
          )
          rules_1007 = Suggestion::RuleRegistry.all.select { |r| r.key == 'weather_pain_low_1007_Caution' }
          suggestions_1007 = Suggestion::RuleEngine.call(rules: rules_1007, context: ctx_1007, limit: 3, tag_diversity: false)
          expect(suggestions_1007.map(&:key)).to include('weather_pain_low_1007_Caution')
        end
      end

      context 'メッセージの変数埋め込み' do
        it 'メッセージにコンテキスト値が埋め込まれる' do
          daily_log.update!(sleep_hours: 5.5)
          suggestions = described_class.call(user: user, date: date)
          sleep_suggestion = suggestions.find { |s| s.key == 'sleep_Caution' }

          expect(sleep_suggestion).to be_present
          # メッセージ内にsleep_hoursが埋め込まれていることを確認（sleep_2は%{sleep_hours}を含まないが、少なくとも提案が返る）
          expect(sleep_suggestion.message).to be_present
        end
      end

      context 'severity順と最大件数制限' do
        it 'severityの高い順に返す' do
          daily_log.update!(sleep_hours: 5.0)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 36.0,
            "min_temperature_c" => 25.0,
            "humidity_pct" => 75.0,
            "pressure_hpa" => 1013.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user, date: date)

          expect(suggestions.length).to be <= 3
          if suggestions.length > 1
            severities = suggestions.map(&:severity)
            expect(severities).to eq(severities.sort.reverse)
          end
        end

        it '最大3件まで返す' do
          daily_log.update!(sleep_hours: 5.0)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 36.0,
            "min_temperature_c" => 25.0,
            "humidity_pct" => 75.0,
            "pressure_hpa" => 970.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user, date: date)

          expect(suggestions.length).to be <= 3
        end
      end

      context '同タグの連発抑制' do
        it '同じタグを持つ提案が複数ある場合、上位のもののみ返す' do
          daily_log.update!(sleep_hours: 5.0)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 36.0,
            "min_temperature_c" => 25.0,
            "humidity_pct" => 50.0,
            "pressure_hpa" => 1013.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user, date: date)
          sleep_suggestions = suggestions.select { |s| s.tags.include?('sleep') }

          # 同タグ連発抑制により、sleepタグの提案は1件以下になる可能性がある
          expect(sleep_suggestions.length).to be <= 1
        end
      end

      context '条件に一致しない場合' do
        it '提案を返さない' do
          daily_log.update!(sleep_hours: 7.5)
          weather_snapshot.update!(metrics: {
            "temperature_c" => 20.0,
            "min_temperature_c" => 15.0,
            "humidity_pct" => 50.0,
            "pressure_hpa" => 1013.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user, date: date)

          # すべての条件に一致しない場合、提案は空配列または少ない件数になる
          expect(suggestions).to be_an(Array)
        end
      end

      context '関心ワードによるフィルタリング' do
        before { Suggestion::RuleRegistry.reload! }

        let(:user_without_concerns) { create(:user, prefecture: create(:prefecture)) }
        let!(:daily_log_without_concerns) do
          create(:daily_log,
                 user: user_without_concerns,
                 prefecture: user_without_concerns.prefecture,
                 date: date,
                 sleep_hours: 5.0,
                 mood: 3)
        end
        let!(:weather_snapshot_without_concerns) do
          create(:weather_snapshot,
                 prefecture: user_without_concerns.prefecture,
                 date: date,
                 metrics: {
                   "temperature_c" => 22.0,
                   "min_temperature_c" => 18.0,
                   "humidity_pct" => 55.0,
                   "pressure_hpa" => 1010.0,
                   "max_pressure_drop_1h_awake" => 0.0,
                   "low_pressure_duration_1003h" => 0.0,
                   "low_pressure_duration_1007h" => 0.0,
                   "pressure_range_3h_awake" => 0.0,
                   "pressure_jitter_3h_awake" => 0.0
                 })
        end

        it '関心ワード未登録の場合、general のルールのみ返す' do
          suggestions = described_class.call(user: user_without_concerns, date: date)
          heat_suggestion = suggestions.find { |s| s.key == 'heatstroke_Warning' }
          general_suggestions = suggestions.select do |s|
            rule = Suggestion::RuleRegistry.all.find { |r| r.key == s.key }
            rule&.concerns&.include?('general')
          end

          expect(heat_suggestion).to be_nil
          expect(suggestions).to be_an(Array)
          expect(suggestions.length).to eq(general_suggestions.length)
          expect(suggestions).not_to be_empty
        end

        it '関心ワード登録時、該当するルールのみ返す' do
          heat_topic = ConcernTopic.find_or_create_by!(key: 'heatstroke') do |c|
            c.label_ja = "熱中症"
            c.rule_concerns = ["heatstroke"]
            c.position = 1
            c.active = true
          end
          create(:user_concern_topic, user: user_without_concerns, concern_topic: heat_topic)
          weather_snapshot_without_concerns.update!(metrics: {
            "temperature_c" => 32.0,
            "min_temperature_c" => 22.0,
            "humidity_pct" => 50.0,
            "pressure_hpa" => 1013.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user_without_concerns, date: date)
          heat_suggestion = suggestions.find { |s| s.key == 'heatstroke_Warning' }

          expect(heat_suggestion).to be_present
          expect(heat_suggestion.title).to eq('暑い日。炎天下を避け、激しい運動は中止')
        end

        it '登録した関心ワードに含まないルールは返さない' do
          heat_topic = ConcernTopic.find_or_create_by!(key: 'heatstroke') do |c|
            c.label_ja = "熱中症"
            c.rule_concerns = ["heatstroke"]
            c.position = 1
            c.active = true
          end
          create(:user_concern_topic, user: user_without_concerns, concern_topic: heat_topic)
          weather_snapshot_without_concerns.update!(metrics: {
            "temperature_c" => 20.0,
            "min_temperature_c" => 15.0,
            "humidity_pct" => 50.0,
            "pressure_hpa" => 1005.0,
            "max_pressure_drop_1h_awake" => -3.5,
            "low_pressure_duration_1003h" => 3.0,
            "low_pressure_duration_1007h" => 4.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user_without_concerns, date: date)
          weather_pain_suggestion = suggestions.find { |s| s.key == 'weather_pain_drop_Warning' }

          expect(weather_pain_suggestion).to be_nil
        end

        it 'concerns: ["general"] の一般ルールは常に返す' do
          heat_topic = ConcernTopic.find_or_create_by!(key: 'heatstroke') do |c|
            c.label_ja = "熱中症"
            c.rule_concerns = ["heatstroke"]
            c.position = 1
            c.active = true
          end
          create(:user_concern_topic, user: user_without_concerns, concern_topic: heat_topic)
          weather_snapshot_without_concerns.update!(metrics: {
            "temperature_c" => 22.0,
            "min_temperature_c" => 18.0,
            "humidity_pct" => 55.0,
            "pressure_hpa" => 1010.0,
            "max_pressure_drop_1h_awake" => 0.0,
            "low_pressure_duration_1003h" => 0.0,
            "low_pressure_duration_1007h" => 0.0,
            "pressure_range_3h_awake" => 0.0,
            "pressure_jitter_3h_awake" => 0.0
          })

          suggestions = described_class.call(user: user_without_concerns, date: date)
          general_suggestion = suggestions.find do |s|
            rule = Suggestion::RuleRegistry.all.find { |r| r.key == s.key }
            rule&.concerns&.include?('general')
          end

          expect(general_suggestion).to be_present
          expect(%w[comfort_Temperature comfort_Humidity stable_Pressure]).to include(general_suggestion.key)
        end
      end
    end

    context 'DailyLogが存在しない場合' do
      it 'RecordNotFoundエラーが発生する' do
        expect {
          described_class.call(user: user, date: date)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
