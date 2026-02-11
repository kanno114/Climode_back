class Api::V1::UserConcernTopicsController < ApplicationController
  include Authenticatable

  # GET /api/v1/user_concern_topics
  # 単一リソースとして、現在のユーザーの関心テーマ一覧を返す
  def show
    keys = current_user.concern_topics.pluck(:key)
    render json: { keys: keys }
  end

  # PUT /api/v1/user_concern_topics
  def update
    keys = extract_keys

    ActiveRecord::Base.transaction do
      current_topic_ids = UserConcernTopic.where(user: current_user).pluck(:concern_topic_id).to_set
      topics_by_key = ConcernTopic.where(key: keys).index_by(&:key)
      submitted_topic_ids = keys.filter_map { |k| topics_by_key[k]&.id }.to_set

      to_add = submitted_topic_ids - current_topic_ids
      to_remove = current_topic_ids - submitted_topic_ids

      if to_add.any?
        UserConcernTopic.insert_all!(
          to_add.map { |topic_id|
            {
              user_id: current_user.id,
              concern_topic_id: topic_id,
              created_at: Time.current,
              updated_at: Time.current
            }
          }
        )
      end

      if to_remove.any?
        UserConcernTopic.where(user: current_user, concern_topic_id: to_remove.to_a).delete_all
      end
    end

    head :no_content
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def extract_keys
    raw = params[:keys]

    keys =
      case raw
      when String
        raw.split(",")
      when Array
        raw
      else
        []
      end

    keys.map { |k| k.to_s.strip }.reject(&:blank?).uniq
  end
end
