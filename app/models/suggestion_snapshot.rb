class SuggestionSnapshot < ApplicationRecord
  belongs_to :prefecture

  validates :date, presence: true
  validates :rule_key, presence: true
  validates :title, presence: true
  validates :severity, presence: true
  validates :category, presence: true

  scope :for_date, ->(date) { where(date: date) }
  scope :for_prefecture, ->(pref) { where(prefecture_id: pref.respond_to?(:id) ? pref.id : pref) }
  scope :for_tags, ->(tags) {
    next all if tags.blank?
    where("tags ?| array[:tags]", tags: tags)
  }
end
