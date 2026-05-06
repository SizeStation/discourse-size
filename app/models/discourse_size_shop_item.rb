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
