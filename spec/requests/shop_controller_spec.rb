# frozen_string_literal: true

require "rails_helper"

describe DiscourseSize::ShopController do
  fab!(:admin)
  fab!(:user)
  fab!(:group_user, :user)
  fab!(:shop_group) { Fabricate(:group, name: "shop_managers") }

  before do
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

  describe "POST #purchase" do
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
