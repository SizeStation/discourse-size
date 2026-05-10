# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSize::QuestManager do
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.discourse_size_enabled = true
    SiteSetting.discourse_size_daily_quests_count = 3
  end

  describe ".ensure_quests_for" do
    it "filters category quests if not configured" do
      SiteSetting.discourse_size_conversation_category_ids = ""
      SiteSetting.discourse_size_content_category_ids = ""
      
      # Clear any existing quests for today
      DiscourseSizeUserQuest.where(user_id: user.id).destroy_all
      
      quests = described_class.ensure_quests_for(user)
      
      # Should not include conv or content quests
      quest_ids = quests.map(&:quest_id)
      expect(quest_ids).not_to include("topic_created_conv")
      expect(quest_ids).not_to include("topic_created_content")
      expect(quest_ids).not_to include("post_created_conv")
      expect(quest_ids).not_to include("post_created_content")
    end

    it "includes category quests if configured" do
      SiteSetting.discourse_size_conversation_category_ids = "1,2"
      
      # Mock QUESTS to only have one
      stub_const("DiscourseSize::QuestManager::QUESTS", [
        { id: "topic_created_conv", type: :topic_created, category_group: :conversation, min: 1, max: 1, reward: 10 }
      ])
      
      # Clear any existing quests for today
      DiscourseSizeUserQuest.where(user_id: user.id).destroy_all
      
      quests = described_class.ensure_quests_for(user)
      expect(quests.map(&:quest_id)).to include("topic_created_conv")
    end
  end

  describe ".track_activity" do
    let!(:quest) { 
      DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 2,
        current_count: 0
      )
    }

    it "increments post_created quest on topic_created activity" do
      described_class.track_activity(user, :topic_created)
      quest.reload
      expect(quest.current_count).to eq(1)
    end

    it "increments post_created quest on post_created activity" do
      described_class.track_activity(user, :post_created)
      quest.reload
      expect(quest.current_count).to eq(1)
    end

    it "handles category matching for subcategories" do
      SiteSetting.discourse_size_content_category_ids = "10"
      parent_cat = Fabricate(:category, id: 10)
      sub_cat = Fabricate(:category, parent_category_id: 10)
      
      content_quest = DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created_content",
        target_count: 1,
        current_count: 0
      )
      
      described_class.track_activity(user, :post_created, category_id: sub_cat.id)
      content_quest.reload
      expect(content_quest.current_count).to eq(1)
    end
  end
end
