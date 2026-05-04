# frozen_string_literal: true

class DiscourseSizeCharacter < ActiveRecord::Base
  belongs_to :user
  before_save :ensure_single_main, if: :is_main?

  validates :name, presence: true
  validates :base_size,
            presence: true,
            numericality: {
              greater_than_or_equal_to: -> { SiteSetting.discourse_size_min_base_size },
              less_than_or_equal_to: -> { SiteSetting.discourse_size_max_base_size },
            }
  validates :user_id, presence: true

  has_many :discourse_size_actions, foreign_key: "character_id", dependent: :destroy

  TYPE_GAME = 'game'
  TYPE_FREEFORM = 'freeform'

  validates :character_type, inclusion: { in: [TYPE_GAME, TYPE_FREEFORM] }

  def game?
    character_type == TYPE_GAME
  end

  def freeform?
    character_type == TYPE_FREEFORM
  end

  MAX_SIZE = 1e120 # Cap at a googol-plus to prevent Infinity overflow

  def update_size_target(amount)
    sync_offset!
    new_target = self.target_offset + amount

    # Cap total size
    if (self.base_size + new_target) > MAX_SIZE
      new_target = MAX_SIZE - self.base_size
    end

    # Floor total size at a nanoscopic value (1e-18 cm) to prevent true zero/negative
    new_target = 1e-18 - self.base_size if (self.base_size + new_target) < 1e-18

    self.target_offset = new_target
    save!
  end

  def current_size
    base_size + current_calculated_offset
  end

  def current_calculated_offset
    # Calculate offset based on target_offset, current_offset, offset_updated_at, and max_growth_rate
    # If target_offset == current_offset, return current_offset
    return current_offset if target_offset == current_offset || offset_updated_at.nil?

    rate_percent_per_day =
      (growth_rate_override || SiteSetting.discourse_size_default_max_growth_rate) +
        growth_rate_bought
    return target_offset if rate_percent_per_day <= 0

    days_elapsed = (Time.now - offset_updated_at) / 86400.0
    current_size = base_size + current_offset
    target_size = base_size + target_offset

    multiplier = (1.0 + rate_percent_per_day / 100.0)**days_elapsed

    if target_offset > current_offset
      new_size = current_size * multiplier
      new_size = target_size if new_size > target_size
      new_size = MAX_SIZE if new_size > MAX_SIZE
    else
      new_size = current_size / multiplier
      new_size = target_size if new_size < target_size
    end

    new_size - base_size
  end

  def sync_offset!
    new_offset = current_calculated_offset
    if new_offset != current_offset
      self.current_offset = new_offset
      self.offset_updated_at = Time.now
      self.save!
    end
  end

  private

  def ensure_single_main
    DiscourseSizeCharacter.where(user_id: user_id, is_main: true).where.not(id: id).update_all(is_main: false)
  end
end

# == Schema Information
#
# Table name: discourse_size_characters
#
#  id                   :bigint           not null, primary key
#  age                  :string
#  allow_growth         :boolean          default(TRUE), not null
#  allow_shrink         :boolean          default(TRUE), not null
#  base_size            :float            not null
#  character_type       :string           default("game"), not null
#  current_offset       :float            default(0.0), not null
#  description          :text
#  gender               :string
#  growth_rate_bought   :float            default(0.0), not null
#  growth_rate_override :float
#  info_post            :string
#  is_main              :boolean          default(FALSE), not null
#  measurement_system   :string           default("imperial"), not null
#  name                 :string           not null
#  offset_updated_at    :datetime         not null
#  picture              :string
#  pronouns             :string
#  show_comparison      :boolean          default(TRUE), not null
#  target_offset        :float            default(0.0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  user_id              :integer          not null
#
# Indexes
#
#  index_discourse_size_characters_on_user_id              (user_id)
#  index_discourse_size_characters_on_user_id_and_is_main  (user_id,is_main) UNIQUE WHERE (is_main = true)
#
