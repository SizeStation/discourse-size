# frozen_string_literal: true

class DiscourseSizeUserSetting < ActiveRecord::Base
  belongs_to :user

  def self.for_user(user)
    find_or_create_by!(user_id: user.id)
  end
end
