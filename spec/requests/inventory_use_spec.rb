# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSize::InventoryController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:character) { Fabricate(:discourse_size_character, user: other_user, base_size: 100.0) }
  fab!(:main_character) do
    Fabricate(
      :discourse_size_character,
      user: user,
      character_type: DiscourseSizeCharacter::TYPE_GAME,
      base_size: 200.0,
      is_main: true,
    )
  end

  let(:item) do
    DiscourseSizeShopItem.create!(
      key: "confirmation_potion",
      name: "Confirmation potion",
      price: 0,
      effect: "shrink",
      amount: 25.0,
      self_effect: "grow",
      self_amount: 25.0,
      duration_minutes: 10,
      uses: 1,
    )
  end
  let(:inventory_item) do
    DiscourseSizeInventory.create!(user: user, item_key: item.key, uses_remaining: 1)
  end
  let(:params) { { inventory_item_id: inventory_item.id, character_id: character.id } }

  describe "#use" do
    before do
      freeze_time Time.zone.now.change(usec: 0)
      SiteSetting.discourse_size_enabled = true
      sign_in(user)
    end

    it "leaves all effects untouched until explicitly confirmed, then consumes and applies self growth" do
      character.update_size(DiscourseSizeCharacter::MIN_SIZE, other_user)
      quest =
        DiscourseSizeUserQuest.create!(
          user_id: user.id,
          quest_id: "character_shrink",
          target_count: 1,
          current_count: 0,
        )
      request_params = params
      original_inventory = inventory_item.reload.attributes
      original_characters = [character, main_character].map { |record| record.reload.attributes }
      original_actions = DiscourseSizeAction.order(:id).map(&:attributes)
      original_quests = DiscourseSizeUserQuest.order(:id).map(&:attributes)
      original_notifications = Notification.order(:id).map(&:attributes)

      [
        {},
        { confirm_no_size_change: "false" },
        { confirm_no_size_change: false },
        { confirm_no_size_change: "1" },
        { confirm_no_size_change: 1 },
        { confirm_no_size_change: "TRUE" },
      ].each do |confirmation|
        post "/size/inventory/use.json", params: request_params.merge(confirmation), as: :json

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(
          "confirmation_required" => true,
          "no_size_effects" => [{ "character_name" => character.name, "reason" => "minimum_size" }],
        )
        expect(inventory_item.reload.attributes).to eq(original_inventory)
        expect([character, main_character].map { |record| record.reload.attributes }).to eq(
          original_characters,
        )
        expect(DiscourseSizeAction.order(:id).map(&:attributes)).to eq(original_actions)
        expect(DiscourseSizeUserQuest.order(:id).map(&:attributes)).to eq(original_quests)
        expect(Notification.order(:id).map(&:attributes)).to eq(original_notifications)
      end

      expect do
        post "/size/inventory/use.json",
             params: request_params.merge(confirm_no_size_change: "true")
      end.to change { DiscourseSizeAction.count }.by(2).and change { Notification.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(DiscourseSizeInventory.exists?(inventory_item.id)).to eq(false)
      expect(quest.reload.current_count).to eq(1)
      target_action = character.discourse_size_actions.find_by!(item_key: item.key)
      expect(main_character.discourse_size_actions.sole).to have_attributes(
        parent_action_id: target_action.id,
        action_type: "grow",
        end_offset: 50.0,
      )
      expect(main_character.reload.target_offset).to eq(50.0)
      expect(character.reload.current_size).to eq(DiscourseSizeCharacter::MIN_SIZE)
    end

    it "accepts a JSON boolean true as confirmation" do
      character.update_size(DiscourseSizeCharacter::MIN_SIZE, other_user)
      request_params = params.merge(confirm_no_size_change: true)

      post "/size/inventory/use.json", params: request_params, as: :json

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(DiscourseSizeInventory.exists?(inventory_item.id)).to eq(false)
      expect(main_character.reload.target_offset).to eq(50.0)
    end

    it "warns for the queued minimum endpoint instead of the current animation or cached target" do
      character.add_queued_action(
        action_type: "shrink",
        size_change: -100.0,
        duration_minutes: 10,
        user_id: other_user.id,
        effect_type: "shrink",
        effect_amount: 100.0,
      )
      character.update_columns(target_offset: 0.0)
      expect(character.current_size).to eq(100.0)
      request_params = params

      expect do post "/size/inventory/use.json", params: request_params end.not_to change {
        DiscourseSizeAction.count
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "confirmation_required" => true,
        "no_size_effects" => [{ "character_name" => character.name, "reason" => "minimum_size" }],
      )
      expect(inventory_item.reload.uses_remaining).to eq(1)
    end

    it "uses the last queued size when the current animation is still at the minimum" do
      character.update_size(DiscourseSizeCharacter::MIN_SIZE, other_user)
      character.add_queued_action(
        action_type: "set_size",
        size_change: 200.0,
        duration_minutes: 10,
        user_id: other_user.id,
        effect_type: "static",
        effect_amount: 200.0,
      )
      expect(character.current_size).to eq(DiscourseSizeCharacter::MIN_SIZE)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(character.reload.target_offset).to eq(50.0)
      expect(DiscourseSizeInventory.exists?(inventory_item.id)).to eq(false)
    end

    it "uses zero offset when there are no size actions despite a stale cached target" do
      character.update_columns(current_offset: -100.0, target_offset: -100.0)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(character.reload.target_offset).to eq(-25.0)
      expect(DiscourseSizeInventory.exists?(inventory_item.id)).to eq(false)
    end

    it "allows representable growth from a base size at the minimum" do
      character.update!(base_size: DiscourseSizeCharacter::MIN_SIZE)
      item.update!(effect: "grow", amount: 100.0, duration_minutes: 0)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(character.reload.current_size).to eq(2 * DiscourseSizeCharacter::MIN_SIZE)
      expect(DiscourseSizeInventory.exists?(inventory_item.id)).to eq(false)
    end

    it "warns when growth from a raw zero total still reconstructs to the minimum" do
      character.update_size(DiscourseSizeCharacter::MIN_SIZE, other_user)
      item.update!(effect: "grow", amount: 100.0)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "confirmation_required" => true,
        "no_size_effects" => [{ "character_name" => character.name, "reason" => "minimum_size" }],
      )
      expect(inventory_item.reload.uses_remaining).to eq(1)
    end

    it "warns about unchanged size when storing the offset loses a shrink above the minimum" do
      character.discourse_size_actions.create!(
        user: other_user,
        action_type: "set_size",
        size_change: -99.99999999999997,
        start_offset: 0.0,
        end_offset: -99.99999999999997,
        start_time: 1.minute.ago,
        end_time: 1.minute.ago,
        duration_minutes: 0,
      )
      expect(character.current_size).to be > DiscourseSizeCharacter::MIN_SIZE
      request_params = params

      expect do post "/size/inventory/use.json", params: request_params end.not_to change {
        DiscourseSizeAction.count
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "confirmation_required" => true,
        "no_size_effects" => [{ "character_name" => character.name, "reason" => "unchanged_size" }],
      )
      expect(inventory_item.reload.uses_remaining).to eq(1)
    end

    it "warns when a static effect already matches the queued size" do
      item.update!(effect: "static", amount: 100.0)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "confirmation_required" => true,
        "no_size_effects" => [{ "character_name" => character.name, "reason" => "unchanged_size" }],
      )
      expect(inventory_item.reload.uses_remaining).to eq(1)
    end

    it "warns about unchanged size for growth capped at the maximum" do
      character.update!(base_size: DiscourseSizeCharacter::MAX_SIZE)
      item.update!(effect: "grow", amount: 100.0)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "confirmation_required" => true,
        "no_size_effects" => [{ "character_name" => character.name, "reason" => "unchanged_size" }],
      )
      expect(inventory_item.reload.uses_remaining).to eq(1)
    end

    it "requires confirmation when only the applicable self effect leaves size unchanged" do
      main_character.update_size(DiscourseSizeCharacter::MIN_SIZE, user)
      item.update!(self_effect: "shrink")
      request_params = params

      expect do post "/size/inventory/use.json", params: request_params end.not_to change {
        DiscourseSizeAction.count
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "confirmation_required" => true,
        "no_size_effects" => [
          { "character_name" => main_character.name, "reason" => "minimum_size" },
        ],
      )
      expect(inventory_item.reload.uses_remaining).to eq(1)
      expect(character.reload.target_offset).to eq(0.0)
    end

    it "reports both characters when neither effect changes size" do
      character.update_size(DiscourseSizeCharacter::MIN_SIZE, other_user)
      main_character.update_size(DiscourseSizeCharacter::MIN_SIZE, user)
      item.update!(self_effect: "shrink")

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body["confirmation_required"]).to eq(true)
      expect(response.parsed_body["no_size_effects"]).to contain_exactly(
        { "character_name" => character.name, "reason" => "minimum_size" },
        { "character_name" => main_character.name, "reason" => "minimum_size" },
      )
      expect(inventory_item.reload.uses_remaining).to eq(1)
    end

    it "skips the self effect when targeting another character owned by the actor" do
      character.update!(user: user)
      main_character.update_size(DiscourseSizeCharacter::MIN_SIZE, user)
      item.update!(self_effect: "shrink")
      original_main_actions = main_character.discourse_size_actions.map(&:attributes)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(character.reload.target_offset).to eq(-25.0)
      expect(main_character.discourse_size_actions.reload.map(&:attributes)).to eq(
        original_main_actions,
      )
      expect(DiscourseSizeInventory.exists?(inventory_item.id)).to eq(false)
    end

    it "skips the self effect for a normal main character" do
      main_character.update!(character_type: DiscourseSizeCharacter::TYPE_NORMAL)
      item.update!(self_effect: "static", self_amount: 200.0)

      post "/size/inventory/use.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(character.reload.target_offset).to eq(-25.0)
      expect(main_character.discourse_size_actions).to be_empty
      expect(DiscourseSizeInventory.exists?(inventory_item.id)).to eq(false)
    end
  end
end
