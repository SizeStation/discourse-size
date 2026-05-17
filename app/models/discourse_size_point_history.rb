# frozen_string_literal: true

class DiscourseSizePointHistory < ActiveRecord::Base
  self.table_name = "discourse_size_point_history"
  belongs_to :user

  validates :user_id, presence: true
  validates :amount, presence: true
  validates :source_type, presence: true

  # Source types: 
  # - admin_correction
  # - grow_character
  # - shrink_character
  # - purchase_item
  # - daily_login
  # - invite_reward
  # - post_reward
  # - read_reward
end

# == Schema Information
#
# Table name: discourse_size_point_history
#
#  id          :bigint           not null, primary key
#  amount      :float            not null
#  description :text
#  source_type :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_discourse_size_point_history_on_user_id  (user_id)
#
