# frozen_string_literal: true

require "rails_helper"

describe DiscourseSize::ShopController do
  fab!(:admin)
  fab!(:user)
  fab!(:group_user, :user)
  fab!(:shop_group) { Fabricate(:group, name: "shop_managers") }

  let(:shop_item) do
    DiscourseSizeShopItem.create!(
      key: "retirement_potion",
      name: "Retirement potion",
      price: 10,
      effect: "grow",
      amount: 50.0,
      uses: 2,
      stock: 5,
      enabled: true,
    )
  end

  before do
    SiteSetting.discourse_size_enabled = true
    shop_group.add(group_user)
    SiteSetting.discourse_size_shop_manager_group = "shop_managers"
  end

  it "allows shop group member to manage shop items via Guardian" do
    expect(Guardian.new(group_user).can_manage_size_shop?).to be true
  end

  it "denies regular user from managing shop items via Guardian" do
    expect(Guardian.new(user).can_manage_size_shop?).to be false
  end

  it "allows admin to manage shop items via Guardian" do
    expect(Guardian.new(admin).can_manage_size_shop?).to be true
  end

  describe "#index" do
    it "hides retired items from visitors, regular users, admins, and shop managers" do
      shop_item.update!(deleted_at: Time.current, enabled: false)
      available_item = shop_item.dup
      available_item.update!(key: "available_potion", deleted_at: nil, enabled: true)
      disabled_item = available_item.dup
      disabled_item.update!(key: "disabled_available_potion", enabled: false)

      get "/size/shop.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["items"].pluck("key")).to contain_exactly(available_item.key)

      [user, admin, group_user].each do |viewer|
        sign_in(viewer)

        get "/size/shop.json"

        expect(response.status).to eq(200)
        expected_keys =
          viewer == user ? [available_item.key] : [available_item.key, disabled_item.key]
        expect(response.parsed_body["items"].pluck("key")).to match_array(expected_keys)
      end
    end
  end

  describe "#destroy" do
    before { sign_in(group_user) }

    it "retires the definition without removing inventories or their remaining uses" do
      freeze_time Time.current.change(usec: 0)
      inventories =
        [user, group_user].map do |owner|
          DiscourseSizeInventory.create!(user: owner, item_key: shop_item.key, uses_remaining: 2)
        end
      original_inventories = inventories.map(&:attributes)

      delete "/size/admin/shop_items/#{shop_item.id}.json"

      expect(response.status).to eq(200)
      expect(shop_item.reload).to have_attributes(deleted_at: Time.current, enabled: false)
      expect(inventories.map { |inventory| inventory.reload.attributes }).to eq(
        original_inventories,
      )
    end

    it "keeps retired inventory usable and refundable through the existing endpoints" do
      character = Fabricate(:discourse_size_character, user: user)
      inventory =
        DiscourseSizeInventory.create!(user: user, item_key: shop_item.key, uses_remaining: 2)

      delete "/size/admin/shop_items/#{shop_item.id}.json"
      expect(response.status).to eq(200)

      sign_in(user)
      post "/size/inventory/use.json",
           params: {
             inventory_item_id: inventory.id,
             character_id: character.id,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq(true)
      expect(inventory.reload.uses_remaining).to eq(1)
      action = character.discourse_size_actions.find_by!(item_key: shop_item.key)

      delete "/size/actions/#{action.id}.json"

      expect(response.status).to eq(200)
      expect(inventory.reload.uses_remaining).to eq(2)
      expect(shop_item.reload.deleted_at).to be_present
    end
  end

  describe "#create" do
    it "keeps a retired item's key reserved" do
      shop_item.update!(deleted_at: Time.current, enabled: false)
      sign_in(group_user)

      post "/size/admin/shop_items.json",
           params: {
             key: shop_item.key,
             name: "Replacement",
             price: 0,
             effect: "grow",
             amount: 10,
             uses: 1,
           }

      expect(response.status).to eq(422)
      expect(DiscourseSizeShopItem.where(key: shop_item.key).pluck(:id)).to eq([shop_item.id])
    end
  end

  describe "#update" do
    it "rejects attempts to edit or re-enable a retired item" do
      shop_item.update!(deleted_at: Time.current, enabled: false)
      sign_in(admin)

      put "/size/admin/shop_items/#{shop_item.id}.json", params: { enabled: true, amount: 100 }

      expect(response.status).to eq(404)
      expect(shop_item.reload).to have_attributes(enabled: false, amount: 50.0)
    end
  end

  describe "#reorder" do
    it "ignores retired items while reordering available items" do
      shop_item.update!(deleted_at: Time.current, enabled: false, position: 5)
      available_item = shop_item.dup
      available_item.update!(key: "reordered_potion", deleted_at: nil, position: 10)
      sign_in(group_user)

      post "/size/admin/shop_items/reorder.json", params: { ids: [available_item.id, shop_item.id] }

      expect(response.status).to eq(200)
      expect(available_item.reload.position).to eq(0)
      expect(shop_item.reload.position).to eq(5)
    end
  end

  describe "#purchase" do
    fab!(:enabled_item) do
      DiscourseSizeShopItem.create!(
        key: "enabled_potion",
        name: "Enabled Potion",
        price: 10,
        effect: "grow",
        amount: 50.0,
        uses: 1,
        stock: 5,
        enabled: true,
      )
    end

    fab!(:disabled_item) do
      DiscourseSizeShopItem.create!(
        key: "disabled_potion",
        name: "Disabled Potion",
        price: 10,
        effect: "shrink",
        amount: 20.0,
        uses: 1,
        stock: 5,
        enabled: false,
      )
    end

    fab!(:out_of_stock_disabled_item) do
      DiscourseSizeShopItem.create!(
        key: "oos_disabled_potion",
        name: "OOS Disabled Potion",
        price: 10,
        effect: "shrink",
        amount: 20.0,
        uses: 1,
        stock: 0,
        enabled: false,
      )
    end

    before do
      DiscourseSize::PointsManager.add_points(user, 50)
      DiscourseSize::PointsManager.add_points(admin, 50)
      DiscourseSize::PointsManager.add_points(group_user, 50)
    end

    it "rejects retired items for regular users, admins, and shop managers without charging them" do
      shop_item.update!(deleted_at: Time.current, enabled: false)

      [user, admin, group_user].each do |buyer|
        sign_in(buyer)
        original_points = DiscourseSize::PointsManager.get_points(buyer)

        post "/size/shop/purchase.json", params: { item_key: shop_item.key }

        expect(response.status).to eq(422)
        expect(response.parsed_body["failed"]).to eq(true)
        expect(DiscourseSize::PointsManager.get_points(buyer)).to eq(original_points)
        expect(
          DiscourseSizeInventory.where(user_id: buyer.id, item_key: shop_item.key),
        ).not_to exist
      end

      expect(shop_item.reload).to have_attributes(stock: 5, purchase_count: 0)
    end

    it "allows regular user to purchase enabled items" do
      sign_in(user)
      post "/size/shop/purchase.json", params: { item_key: enabled_item.key }
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to be true
      expect(DiscourseSizeInventory.where(user_id: user.id, item_key: enabled_item.key)).to exist
    end

    it "prevents regular user from purchasing disabled items" do
      sign_in(user)
      post "/size/shop/purchase.json", params: { item_key: disabled_item.key }
      expect(response.status).to eq(422)
      expect(response.parsed_body["failed"]).to be true
      expect(
        DiscourseSizeInventory.where(user_id: user.id, item_key: disabled_item.key),
      ).not_to exist
    end

    it "allows admin to purchase disabled items" do
      sign_in(admin)
      post "/size/shop/purchase.json", params: { item_key: disabled_item.key }
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to be true
      expect(DiscourseSizeInventory.where(user_id: admin.id, item_key: disabled_item.key)).to exist
    end

    it "allows shop group manager to purchase disabled items" do
      sign_in(group_user)
      post "/size/shop/purchase.json", params: { item_key: disabled_item.key }
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to be true
      expect(
        DiscourseSizeInventory.where(user_id: group_user.id, item_key: disabled_item.key),
      ).to exist
    end

    it "prevents purchasing disabled items when out of stock" do
      sign_in(group_user)
      post "/size/shop/purchase.json", params: { item_key: out_of_stock_disabled_item.key }
      expect(response.status).to eq(422)
      expect(response.parsed_body["failed"]).to be true
    end
  end
end
