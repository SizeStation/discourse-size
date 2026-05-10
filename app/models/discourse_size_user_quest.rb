# frozen_string_literal: true

class DiscourseSizeUserQuest < ActiveRecord::Base
  belongs_to :user

  validates :user_id, presence: true
  validates :quest_id, presence: true
  validates :target_count, presence: true, numericality: { greater_than: 0 }
  validates :current_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reward, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :today, -> { where("created_at >= ?", Time.zone.now.beginning_of_day) }
  scope :uncollected, -> { where(collected: false) }
  scope :collected, -> { where(collected: true) }

  def completed?
    current_count >= target_count
  end
end
