# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSizeShopItem do
  it "validates effect inclusion including static" do
    item = DiscourseSizeShopItem.new(
      key: "static_potion",
      name: "Static Potion",
      price: 10,
      effect: "static",
      amount: 150.0,
      uses: 1
    )
    expect(item).to be_valid
  end

  it "rejects invalid effects" do
    item = DiscourseSizeShopItem.new(
      key: "bad_potion",
      name: "Bad Potion",
      price: 10,
      effect: "invalid_effect",
      amount: 150.0,
      uses: 1
    )
    expect(item).not_to be_valid
  end

  it "allows setting can_only_use_on_self and warning_text" do
    item = DiscourseSizeShopItem.new(
      key: "warning_potion",
      name: "Warning Potion",
      price: 10,
      effect: "grow",
      amount: 150.0,
      uses: 1,
      can_only_use_on_self: true,
      warning_text: "Be careful with this potion!"
    )
    expect(item).to be_valid
    expect(item.can_only_use_on_self).to be true
    expect(item.warning_text).to eq("Be careful with this potion!")
  end
end
