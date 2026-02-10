class Api::V1::ConcernTopicsController < ApplicationController
  include Authenticatable

  # GET /api/v1/concern_topics
  def index
    topics = ConcernTopic.active

    render json: topics.as_json(
      only: [ :key, :label_ja, :description_ja, :rule_concerns ]
    )
  end
end
