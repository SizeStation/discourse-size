# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSize::QuestManager do
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.discourse_size_enabled = true
    SiteSetting.discourse_size_daily_quests_count = 3
  end

  describe ".ensure_quests_for" do
    it "persists quests across days" do
      # Create a quest from yesterday
      quest = DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 1,
        created_at: 1.day.ago
      )
      
      quests = described_class.ensure_quests_for(user)
      expect(quests.count).to eq(1)
      expect(quests.first.id).to eq(quest.id)
    end

    it "generates new quests if none exist" do
      DiscourseSizeUserQuest.where(user_id: user.id).destroy_all
      quests = described_class.ensure_quests_for(user)
      expect(quests.count).to eq(3)
    end
  end

  describe ".can_get_new_quests?" do
    it "returns true if quests are from a previous day" do
      DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 1,
        created_at: 1.day.ago
      )
      expect(described_class.can_get_new_quests?(user)).to be true
    end

    it "returns false if quests are from today" do
      DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 1,
        created_at: Time.zone.now
      )
      expect(described_class.can_get_new_quests?(user)).to be false
    end
  end

  describe ".get_new_quests" do
    it "replaces old quests with new ones" do
      old_quest = DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 1,
        created_at: 1.day.ago
      )
      
      result = described_class.get_new_quests(user)
      expect(result[:success]).to be true
      expect(DiscourseSizeUserQuest.exists?(id: old_quest.id)).to be false
      expect(DiscourseSizeUserQuest.where(user_id: user.id).count).to eq(3)
    end

    it "fails if quests were created today" do
      DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 1,
        created_at: Time.zone.now
      )
      
      result = described_class.get_new_quests(user)
      expect(result[:success]).to be false
    end
  end

  describe ".reroll" do
    it "preserves completed quests" do
      completed = DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "topic_created",
        target_count: 1,
        current_count: 1,
        created_at: Time.zone.now
      )
      
      incomplete = DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 2,
        current_count: 0,
        created_at: Time.zone.now
      )
      
      result = described_class.reroll(user)
      expect(result[:success]).to be true
      
      expect(DiscourseSizeUserQuest.exists?(id: completed.id)).to be true
      expect(DiscourseSizeUserQuest.exists?(id: incomplete.id)).to be false
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
  end
end
