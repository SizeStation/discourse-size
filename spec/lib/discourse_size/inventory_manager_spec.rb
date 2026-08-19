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

  describe "refunding / deleting actions" do
    before do
      DiscourseSizeShopItem.create!(
        key: "grow_50",
        name: "Grow 50%",
        price: 10,
        effect: "grow",
        amount: 50.0,
        uses: 1,
        duration_minutes: 0
      )
      DiscourseSizeShopItem.create!(
        key: "grow_100",
        name: "Grow 100%",
        price: 20,
        effect: "grow",
        amount: 100.0,
        uses: 1,
        duration_minutes: 0
      )
      DiscourseSizeShopItem.create!(
        key: "shrink_20",
        name: "Shrink 20%",
        price: 15,
        effect: "shrink",
        amount: 20.0,
        uses: 1,
        duration_minutes: 0
      )
    end

    it "recalculates subsequent items correctly when an earlier item is refunded" do
      inv1 = DiscourseSizeInventory.create!(user_id: user.id, item_key: "grow_50", uses_remaining: 1)
      inv2 = DiscourseSizeInventory.create!(user_id: user.id, item_key: "grow_100", uses_remaining: 1)
      inv3 = DiscourseSizeInventory.create!(user_id: user.id, item_key: "shrink_20", uses_remaining: 1)

      DiscourseSize::InventoryManager.use_item(user, inv1.id, character.id)
      character.reload
      expect(character.target_offset).to eq(50.0) # 100 * 1.5 = 150 cm

      DiscourseSize::InventoryManager.use_item(user, inv2.id, character.id)
      character.reload
      expect(character.target_offset).to eq(200.0) # 150 * 2.0 = 300 cm

      DiscourseSize::InventoryManager.use_item(user, inv3.id, character.id)
      character.reload
      expect(character.target_offset).to eq(140.0) # 300 * 0.8 = 240 cm

      # Refund first item (grow_50)
      action1 = character.discourse_size_actions.find_by(item_key: "grow_50")
      action1.destroy
      character.reload.recalculate_pending_actions!

      # Remaining: grow_100 (100 * 2.0 = 200 cm) then shrink_20 (200 * 0.8 = 160 cm)
      character.reload
      expect(character.target_offset).to eq(60.0)
      expect(character.current_size).to eq(160.0)

      # Refund second item (grow_100)
      action2 = character.discourse_size_actions.find_by(item_key: "grow_100")
      action2.destroy
      character.reload.recalculate_pending_actions!

      # Remaining: shrink_20 (100 * 0.8 = 80 cm)
      character.reload
      expect(character.target_offset).to eq(-20.0)
      expect(character.current_size).to eq(80.0)

      # Refund last item (shrink_20)
      action3 = character.discourse_size_actions.find_by(item_key: "shrink_20")
      action3.destroy
      character.reload.recalculate_pending_actions!

      # No items left -> back to base size (100 cm)
      character.reload
      expect(character.target_offset).to eq(0.0)
      expect(character.current_size).to eq(100.0)
    end
  end

  describe "item blocking" do
    fab!(:other_user, :user)

    before do
      DiscourseSizeShopItem.create!(
        key: "grow_potion",
        name: "Grow Potion",
        price: 10,
        effect: "grow",
        amount: 50.0,
        uses: 1
      )
      DiscourseSizeShopItem.create!(
        key: "shrink_potion",
        name: "Shrink Potion",
        price: 10,
        effect: "shrink",
        amount: 20.0,
        uses: 1
      )
      DiscourseSizeShopItem.create!(
        key: "bundle_splash_shrink",
        name: "Bundle of Splash Shrink Potions",
        price: 15,
        effect: "shrink",
        amount: 30.0,
        uses: 1
      )
    end

    it "blocks newly added shrinking items when __all_shrinking__ is set" do
      character.update!(blocked_item_keys: ["__all_shrinking__"])

      inv = DiscourseSizeInventory.create!(user_id: other_user.id, item_key: "bundle_splash_shrink", uses_remaining: 1)
      result = DiscourseSize::InventoryManager.use_item(other_user, inv.id, character.id)
      expect(result[:error]).to be_present

      # Grow items are not blocked
      inv_grow = DiscourseSizeInventory.create!(user_id: other_user.id, item_key: "grow_potion", uses_remaining: 1)
      result_grow = DiscourseSize::InventoryManager.use_item(other_user, inv_grow.id, character.id)
      expect(result_grow[:success]).to be true
    end

    it "blocks both shrinking and growing items when both __all_shrinking__ and __all_growing__ are set" do
      character.update!(blocked_item_keys: ["__all_shrinking__", "__all_growing__"])

      inv_shrink = DiscourseSizeInventory.create!(user_id: other_user.id, item_key: "bundle_splash_shrink", uses_remaining: 1)
      result_shrink = DiscourseSize::InventoryManager.use_item(other_user, inv_shrink.id, character.id)
      expect(result_shrink[:error]).to be_present

      inv_grow = DiscourseSizeInventory.create!(user_id: other_user.id, item_key: "grow_potion", uses_remaining: 1)
      result_grow = DiscourseSize::InventoryManager.use_item(other_user, inv_grow.id, character.id)
      expect(result_grow[:error]).to be_present
    end

    it "blocks all shrinking and specific growing items when combined" do
      character.update!(blocked_item_keys: ["__all_shrinking__", "grow_potion"])

      inv_shrink = DiscourseSizeInventory.create!(user_id: other_user.id, item_key: "shrink_potion", uses_remaining: 1)
      expect(DiscourseSize::InventoryManager.use_item(other_user, inv_shrink.id, character.id)[:error]).to be_present

      inv_grow = DiscourseSizeInventory.create!(user_id: other_user.id, item_key: "grow_potion", uses_remaining: 1)
      expect(DiscourseSize::InventoryManager.use_item(other_user, inv_grow.id, character.id)[:error]).to be_present
    end

    it "allows the owner to use items regardless of block settings" do
      character.update!(blocked_item_keys: ["__all__"])

      inv = DiscourseSizeInventory.create!(user_id: user.id, item_key: "grow_potion", uses_remaining: 1)
      result = DiscourseSize::InventoryManager.use_item(user, inv.id, character.id)
      expect(result[:success]).to be true
    end
  end

  describe "self and others restrictions" do
    fab!(:other_user, :user)
    fab!(:other_character) { Fabricate(:discourse_size_character, user: other_user, base_size: 100.0, current_offset: 0.0, target_offset: 0.0, character_type: DiscourseSizeCharacter::TYPE_GAME) }

    before do
      DiscourseSizeShopItem.create!(
        key: "self_only_potion",
        name: "Self Only Potion",
        price: 10,
        effect: "grow",
        amount: 20.0,
        uses: 1,
        can_only_use_on_self: true
      )
      DiscourseSizeShopItem.create!(
        key: "others_only_potion",
        name: "Others Only Potion",
        price: 10,
        effect: "grow",
        amount: 20.0,
        uses: 1,
        can_only_use_on_others: true
      )
    end

    it "allows can_only_use_on_self items on own character and rejects on others" do
      inv_self = DiscourseSizeInventory.create!(user_id: user.id, item_key: "self_only_potion", uses_remaining: 1)
      result_on_other = DiscourseSize::InventoryManager.use_item(user, inv_self.id, other_character.id)
      expect(result_on_other[:error]).to eq("This item can only be used on your own characters.")

      result_on_self = DiscourseSize::InventoryManager.use_item(user, inv_self.id, character.id)
      expect(result_on_self[:success]).to be true
    end

    it "allows can_only_use_on_others items on other characters and rejects on own character" do
      inv_others = DiscourseSizeInventory.create!(user_id: user.id, item_key: "others_only_potion", uses_remaining: 1)
      result_on_self = DiscourseSize::InventoryManager.use_item(user, inv_others.id, character.id)
      expect(result_on_self[:error]).to eq("This item can only be used on other users' characters.")

      result_on_other = DiscourseSize::InventoryManager.use_item(user, inv_others.id, other_character.id)
      expect(result_on_other[:success]).to be true
    end
  end
end
