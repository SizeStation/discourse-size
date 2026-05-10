# frozen_string_literal: true

class DiscourseSizeUserQuestSerializer < ApplicationSerializer
  attributes :id,
             :quest_id,
             :target_count,
             :current_count,
             :collected,
             :reward,
             :completed,
             :emoji

  def completed
    object.completed?
  end

  def emoji
    DiscourseSize::QuestManager::QUESTS.find { |q| q[:id] == object.quest_id }&.[](:emoji)
  end
end
