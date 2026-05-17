# frozen_string_literal: true

class DiscourseSizeUserSetting < ActiveRecord::Base
  belongs_to :user

  def self.for_user(user)
    find_or_create_by!(user_id: user.id)
  end

  self.ignored_columns = ["hide_reward_notice"]
end

# == Schema Information
#
# Table name: discourse_size_user_settings
#
#  id                 :bigint           not null, primary key
#  measurement_system :string           default("imperial"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_discourse_size_user_settings_on_user_id  (user_id) UNIQUE
#
