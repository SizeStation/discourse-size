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
