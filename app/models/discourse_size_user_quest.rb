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

# == Schema Information
#
# Table name: discourse_size_user_quests
#
#  id            :bigint           not null, primary key
#  collected     :boolean          default(FALSE), not null
#  current_count :integer          default(0), not null
#  reward        :integer          default(0), not null
#  target_count  :integer          default(1), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  quest_id      :string           not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_discourse_size_user_quests_on_user_id                 (user_id)
#  index_discourse_size_user_quests_on_user_id_and_created_at  (user_id,created_at)
#
