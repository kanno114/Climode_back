require 'rails_helper'

RSpec.describe Signal::EvaluationService do
  let(:user) { create(:user, prefecture: create(:prefecture)) }
  let(:date) { Date.current }
  let(:service) { described_class.new(user, date) }

  describe '.evaluate_for_user' do
    let!(:trigger) { create(:trigger, key: "pressure_drop", category: "env", is_active: true) }
    let!(:user_trigger) { create(:user_trigger, user: user, trigger: trigger) }
    let!(:weather_snapshot) do
      create(:weather_snapshot, 
             prefecture: user.prefecture, 
             date: date,
             metrics: { "pressure_drop_6h" => -7.0 })
    end

    it 'シグナルイベントを作成する' do
      expect {
        described_class.evaluate_for_user(user, date)
      }.to change(SignalEvent, :count).by(1)
    end
  end

  describe '#evaluate_trigger' do
    let!(:trigger) do
      create(:trigger,
             key: "pressure_drop",
             category: "env",
             is_active: true,
             rule: {
               "metric" => "pressure_drop_6h",
               "operator" => "lte",
               "levels" => [
                 { "id" => "attention", "label" => "注意", "threshold" => -3.0, "priority" => 50 },
                 { "id" => "strong", "label" => "警戒", "threshold" => -6.0, "priority" => 80 }
               ]
             })
    end

    context 'env系トリガーの場合' do
      let!(:weather_snapshot) do
        create(:weather_snapshot,
               prefecture: user.prefecture,
               date: date,
               metrics: { "pressure_drop_6h" => -7.0 })
      end

      it '条件に一致する場合、SignalEventを作成する' do
        expect {
          service.evaluate_trigger(trigger)
        }.to change(SignalEvent, :count).by(1)

        event = SignalEvent.last
        expect(event.trigger_key).to eq("pressure_drop")
        expect(event.category).to eq("env")
        expect(event.level).to eq("strong")
        expect(event.priority).to eq(80)
      end

      it '条件に一致しない場合、SignalEventを作成しない' do
        weather_snapshot.update!(metrics: { "pressure_drop_6h" => -2.0 })

        expect {
          service.evaluate_trigger(trigger)
        }.not_to change(SignalEvent, :count)
      end
    end

    context 'body系トリガーの場合' do
      let!(:trigger) do
        create(:trigger,
               key: "sleep_shortage",
               category: "body",
               is_active: true,
               rule: {
                 "metric" => "sleep_hours",
                 "operator" => "lte",
                 "levels" => [
                   { "id" => "attention", "label" => "注意", "threshold" => 6.0, "priority" => 35 },
                   { "id" => "warning", "label" => "警戒", "threshold" => 4.5, "priority" => 65 }
                 ]
               })
      end
      let!(:daily_log) { create(:daily_log, user: user, date: date, sleep_hours: 5.0) }

      it '条件に一致する場合、SignalEventを作成する' do
        expect {
          service.evaluate_trigger(trigger)
        }.to change(SignalEvent, :count).by(1)

        event = SignalEvent.last
        expect(event.trigger_key).to eq("sleep_shortage")
        expect(event.category).to eq("body")
        expect(event.level).to eq("attention")
        expect(event.priority).to eq(35)
      end
    end
  end
end

