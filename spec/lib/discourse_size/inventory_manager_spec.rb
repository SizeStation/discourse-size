# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSize::InventoryManager do
  fab!(:user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 100.0, current_offset: 0.0, target_offset: 0.0, character_type: DiscourseSizeCharacter::TYPE_GAME) }

  before do
    DiscourseSizeShopItem.create!(
      key: "static_potion",
      name: "Static Potion",
      price: 10,
      effect: "static",
      amount: 250.0,
      uses: 1
    )
  end

  it "sets target size to static amount when static item is used" do
    inventory_item = DiscourseSizeInventory.create!(
      user_id: user.id,
      item_key: "static_potion",
      uses_remaining: 1
    )

    result = DiscourseSize::InventoryManager.use_item(user, inventory_item.id, character.id)
    expect(result[:success]).to be true

    character.reload
    expect(character.target_offset).to eq(150.0)
  end
end
