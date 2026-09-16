# frozen_string_literal: true

require "rails_helper"

describe DiscourseSize::CharactersController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 100.0) }

  let(:item) do
    DiscourseSizeShopItem.create!(
      key: "refundable_growth",
      name: "Refundable growth",
      price: 0,
      effect: "grow",
      amount: 50.0,
      duration_minutes: 10,
      uses: 1,
    )
  end

  before do
    freeze_time
    SiteSetting.discourse_size_enabled = true
  end

  def use_item(actor: user)
    inventory =
      DiscourseSizeInventory.create!(user: actor, item_key: item.key, uses_remaining: 1)
    result = DiscourseSize::InventoryManager.use_item(actor, inventory.id, character.id)
    expect(result[:success]).to eq(true), result.inspect
    character.discourse_size_actions.order(created_at: :desc, id: :desc).first
  end

  describe "#destroy_action" do
    it "requires authentication and rejects the item user when they do not own the character" do
      action = use_item(actor: other_user)
      original_action = action.reload.attributes

      delete "/size/actions/#{action.id}.json"

      expect(response.status).to eq(403)
      expect(action.reload.attributes).to eq(original_action)

      sign_in(other_user)
      delete "/size/actions/#{action.id}.json"

      expect(response.status).to eq(403)
      expect(action.reload.attributes).to eq(original_action)
      expect(DiscourseSizeInventory.where(user: other_user, item_key: item.key)).to be_empty
    end

    it "lets the owner refund a middle action, returning the use to its actor and only replaying the suffix" do
      prefix = use_item
      middle = use_item(actor: other_user)
      suffix = use_item
      original_prefix = prefix.reload.attributes
      item.update!(amount: 75.0)
      freeze_time 2.minutes.from_now
      sign_in(user)

      delete "/size/actions/#{middle.id}.json"

      expect(response.status).to eq(200)
      response_character = response.parsed_body["character"]["discourse_size_character"]
      expect(response_character).to include("id" => character.id, "target_offset" => 125.0)
      expect(response_character["actions"].pluck("id")).to contain_exactly(prefix.id, suffix.id)
      expect(DiscourseSizeAction.exists?(middle.id)).to eq(false)
      expect(prefix.reload.attributes).to eq(original_prefix)
      expect(suffix.reload).to have_attributes(
        start_offset: 50.0,
        end_offset: 125.0,
        start_time: prefix.end_time,
        end_time: prefix.end_time + 10.minutes,
      )
      expect(
        DiscourseSizeInventory.where(user: other_user, item_key: item.key).sum(:uses_remaining),
      ).to eq(1)
      expect(DiscourseSizeInventory.where(user: user, item_key: item.key)).to be_empty
    end

    it "rejects an owner's attempt to refund a linked self-effect independently" do
      main_character =
        Fabricate(
          :discourse_size_character,
          user: other_user,
          character_type: DiscourseSizeCharacter::TYPE_GAME,
          base_size: 200.0,
          is_main: true,
        )
      item.update!(self_effect: "grow", self_amount: 25.0)
      parent = use_item(actor: other_user)
      child = parent.child_actions.sole
      original_actions = [parent, child].map { |action| action.reload.attributes }
      sign_in(other_user)

      delete "/size/actions/#{child.id}.json"

      expect(response.status).to eq(422)
      expect(response.parsed_body["failed"]).to eq(true)
      expect([parent, child].map { |action| action.reload.attributes }).to eq(original_actions)
      expect(main_character.reload.target_offset).to eq(50.0)
      expect(DiscourseSizeInventory.where(user: other_user, item_key: item.key)).to be_empty
    end

    it "allows an admin to refund another user's action" do
      admin = Fabricate(:admin)
      action = use_item
      sign_in(admin)

      delete "/size/actions/#{action.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["character"]["discourse_size_character"]).to include(
        "id" => character.id,
        "target_offset" => 0.0,
      )
      expect(DiscourseSizeAction.exists?(action.id)).to eq(false)
      expect(
        DiscourseSizeInventory.where(user: user, item_key: item.key).sum(:uses_remaining),
      ).to eq(1)
      expect(DiscourseSizeInventory.where(user: admin, item_key: item.key)).to be_empty
    end
  end
end
