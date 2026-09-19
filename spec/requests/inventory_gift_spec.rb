# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSize::InventoryController do
  fab!(:user)
  fab!(:other_user, :user)

  let!(:inventory_item) do
    DiscourseSizeInventory.create!(user: user, item_key: "gift_potion", uses_remaining: 2)
  end
  let!(:quest) do
    DiscourseSizeUserQuest.create!(
      user: user,
      quest_id: "item_gifted",
      target_count: 1,
      current_count: 0,
    )
  end

  describe "#gift" do
    before do
      SiteSetting.discourse_size_enabled = true
      sign_in(user)
    end

    it "rejects self-gifting without changing inventory, notifications, or quest progress" do
      original_inventory = inventory_item.attributes
      original_notifications = Notification.count

      [user.username, user.username.upcase].each do |username|
        post "/size/inventory/gift.json",
             params: {
               inventory_item_id: inventory_item.id,
               username: username,
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body).to eq(
          "failed" => true,
          "message" => "You cannot gift items to yourself.",
        )
        expect(inventory_item.reload.attributes).to eq(original_inventory)
        expect(Notification.count).to eq(original_notifications)
        expect(quest.reload.current_count).to eq(0)
      end
    end

    it "transfers the item and advances the gifting quest when gifting another user" do
      expect do
        post "/size/inventory/gift.json",
             params: {
               inventory_item_id: inventory_item.id,
               username: other_user.username,
             }
      end.to change { Notification.where(user: other_user).count }.by(1)

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
      expect(inventory_item.reload).to have_attributes(user_id: other_user.id, uses_remaining: 2)
      expect(quest.reload.current_count).to eq(1)
    end
  end
end
