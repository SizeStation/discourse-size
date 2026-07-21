# frozen_string_literal: true

require 'rails_helper'

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
end
