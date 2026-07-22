# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSize::QuestManager do
  fab!(:user)

  before do
    SiteSetting.discourse_size_enabled = true
    SiteSetting.discourse_size_daily_quests_count = 3
  end

  describe ".ensure_quests_for" do
    it "persists quests across days" do
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

    it "ensures no duplicate quests are generated" do
      SiteSetting.discourse_size_daily_quests_count = 5
      DiscourseSizeUserQuest.where(user_id: user.id).destroy_all
      quests = described_class.ensure_quests_for(user)
      quest_ids = quests.map(&:quest_id)
      expect(quest_ids.uniq.count).to eq(quest_ids.count)
    end

    it "ensures topic_created and post_created quests (and siblings) are mutually exclusive" do
      SiteSetting.discourse_size_daily_quests_count = 5
      SiteSetting.discourse_size_conversation_category_ids = "1,2"
      SiteSetting.discourse_size_content_category_ids = "3,4"
      DiscourseSizeUserQuest.where(user_id: user.id).destroy_all

      10.times do
        DiscourseSizeUserQuest.where(user_id: user.id).destroy_all
        quests = described_class.ensure_quests_for(user)
        topic_post_count = quests.count do |q|
          def_type = DiscourseSize::QuestManager::QUESTS.find { |def_q| def_q[:id] == q.quest_id }[:type]
          %i[topic_created post_created].include?(def_type)
        end
        expect(topic_post_count).to be <= 1
      end
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

    it "does not generate topic_created or post_created quests when a topic quest is already kept" do
      DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "topic_created",
        target_count: 1,
        current_count: 1,
        collected: true
      )
      DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_read",
        target_count: 5,
        current_count: 0,
        collected: false
      )

      result = described_class.reroll(user)
      expect(result[:success]).to be true

      all_user_quests = DiscourseSizeUserQuest.where(user_id: user.id)
      topic_post_quests = all_user_quests.select do |q|
        def_type = DiscourseSize::QuestManager::QUESTS.find { |def_q| def_q[:id] == q.quest_id }[:type]
        %i[topic_created post_created].include?(def_type)
      end
      expect(topic_post_quests.count).to eq(1)
    end
  end

  describe ".select_quests" do
    it "prevents selecting both topic_created and post_created variants" do
      selected = described_class.select_quests(5, ["topic_created_conv"])
      topic_post_count = selected.count do |q|
        %i[topic_created post_created].include?(q[:type])
      end
      expect(topic_post_count).to eq(0)
    end

    it "prevents duplicate quest selections" do
      selected = described_class.select_quests(10)
      quest_ids = selected.map { |q| q[:id] }
      expect(quest_ids.uniq.count).to eq(quest_ids.count)
    end
  end

  describe ".track_activity" do
    fab!(:quest) do
      DiscourseSizeUserQuest.create!(
        user_id: user.id,
        quest_id: "post_created",
        target_count: 2,
        current_count: 0
      )
    end

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
