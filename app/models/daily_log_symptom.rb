class DailyLogSymptom < ApplicationRecord
  belongs_to :daily_log
  belongs_to :symptom

  validates :daily_log_id, uniqueness: { scope: :symptom_id }
end
