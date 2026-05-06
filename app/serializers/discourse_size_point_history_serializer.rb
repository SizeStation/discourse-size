# frozen_string_literal: true

class DiscourseSizePointHistorySerializer < ApplicationSerializer
  attributes :id,
             :user_id,
             :amount,
             :description,
             :source_type,
             :created_at

  has_one :user, serializer: UserNameSerializer, embed: :objects
end
