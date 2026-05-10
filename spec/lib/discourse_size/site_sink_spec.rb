# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSize::InventoryManager do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  
  let!(:character) do
    DiscourseSizeCharacter.create!(
      user_id: user.id,
      name: "Target Character",
      base_size: 100.0,
      character_type: "game",
      offset_updated_at: Time.now
    )
  end

  let!(:sink_character) do
    DiscourseSizeCharacter.create!(
      user_id: other_user.id,
      name: "Site Sink",
      base_size: 200.0,
      character_type: "game",
      site_sink: true,
      offset_updated_at: Time.now
    )
  end

  let!(:shop_item) do
    DiscourseSizeShopItem.create!(
      key: "grow_item",
      name: "Grow Item",
      price: 10,
      effect: "grow",
      amount: 10.0,
      duration_minutes: 0,
      enabled: true
    )
  end

  let!(:inventory_item) do
    DiscourseSizeInventory.create!(
      user_id: user.id,
      item_key: shop_item.key,
      uses_remaining: 1
    )
  end

  before do
    SiteSetting.discourse_size_enabled = true
  end

  describe ".use_item" do
    it "duplicates the effect to site sink characters independently" do
      expect {
        described_class.use_item(user, inventory_item.id, character.id)
      }.to change { character.reload.target_offset.round(2) }.by(10.0) # 100 * 0.1
       .and change { sink_character.reload.target_offset.round(2) }.by(20.0) # 200 * 0.1

      sink_action = sink_character.discourse_size_actions.last
      expect(sink_action.parent_action_id).to be_nil
    end

    it "does not duplicate the effect if the item is blocked by the sink character" do
      sink_character.update!(blocked_item_keys: ["grow_item"])
      
      expect {
        described_class.use_item(user, inventory_item.id, character.id)
      }.to change { character.reload.target_offset.round(2) }.by(10.0)
       .and not_change { sink_character.reload.target_offset }
    end

    it "does not duplicate the effect if the user is blocked by the sink character" do
      sink_character.update!(blocked_user_ids: [user.id])
      
      expect {
        described_class.use_item(user, inventory_item.id, character.id)
      }.to change { character.reload.target_offset.round(2) }.by(10.0)
       .and not_change { sink_character.reload.target_offset }
    end
    
    it "does not double-apply if the site sink IS the target" do
       sink_character.update!(site_sink: true)
       
       # Reset inventory item
       inventory_item.update!(uses_remaining: 1)
       
       expect {
         described_class.use_item(user, inventory_item.id, sink_character.id)
       }.to change { sink_character.reload.target_offset.round(2) }.by(20.0)
       # Should only apply once (20.0, not 40.0)
    end
  end
end
