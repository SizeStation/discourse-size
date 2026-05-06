# frozen_string_literal: true

class DiscourseSizeShopItem < ActiveRecord::Base
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :effect, inclusion: { in: %w[grow shrink] }
  validates :amount, numericality: { greater_than: 0 }
  validates :uses, numericality: { greater_than: 0 }
  validates :duration_minutes, numericality: { greater_than_or_equal_to: 0 }

  def duration_minutes
    has_attribute?(:duration_minutes) ? read_attribute(:duration_minutes) : 60
  end

  def duration_minutes=(val)
    write_attribute(:duration_minutes, val) if has_attribute?(:duration_minutes)
  end

  scope :enabled, -> { where(enabled: true) }
  scope :in_stock, -> { where("stock > 0 OR stock = -1") }

  def in_stock?
    stock == -1 || stock > 0
  end

  def decrement_stock!
    return if stock == -1
    update!(stock: stock - 1)
  end
end

# == Schema Information
#
# Table name: discourse_size_shop_items
#
#  id               :bigint           not null, primary key
#  amount           :float            not null
#  description      :text
#  duration_minutes :integer          default(60), not null
#  effect           :string           not null
#  enabled          :boolean          default(TRUE), not null
#  key              :string           not null
#  name             :string           not null
#  picture          :string
#  price            :integer          default(0), not null
#  speed            :float            default(1.0), not null
#  stock            :integer          default(-1), not null
#  uses             :integer          default(1), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_discourse_size_shop_items_on_key  (key) UNIQUE
#
