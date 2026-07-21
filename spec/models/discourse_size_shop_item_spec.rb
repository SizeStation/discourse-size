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
end
