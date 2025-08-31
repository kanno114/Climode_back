class Symptom < ApplicationRecord
  has_many :daily_log_symptoms, dependent: :destroy
  has_many :daily_logs, through: :daily_log_symptoms

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true
end
