class Api::V1::UserConcernTopicsController < ApplicationController
  include Authenticatable

  # GET /api/v1/user_concern_topics
  # 単一リソースとして、現在のユーザーの関心テーマ一覧を返す
  def show
    topics = UserConcernTopic.where(user: current_user).order(:concern_topic_key)
    render json: { keys: topics.pluck(:concern_topic_key) }
  end

  # PUT /api/v1/user_concern_topics
  def update
    keys = extract_keys

    ActiveRecord::Base.transaction do
      current_keys = UserConcernTopic.where(user: current_user).pluck(:concern_topic_key).to_set
      submitted_keys = keys.to_set

      to_add = submitted_keys - current_keys
      to_remove = current_keys - submitted_keys

      if to_add.any?
        UserConcernTopic.insert_all!(
          to_add.map { |k|
            {
              user_id: current_user.id,
              concern_topic_key: k,
              created_at: Time.current,
              updated_at: Time.current
            }
          }
        )
      end

      if to_remove.any?
        UserConcernTopic.where(user: current_user, concern_topic_key: to_remove.to_a).delete_all
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
