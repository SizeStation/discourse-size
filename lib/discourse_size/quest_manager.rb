# frozen_string_literal: true

module ::DiscourseSize
  class QuestManager
    QUESTS = [
      { id: "topic_created", type: :topic_created, min: 1, max: 2, reward: 15, emoji: "📝" },
      { id: "topic_created_conv", type: :topic_created, category_group: :conversation, min: 1, max: 2, reward: 15, emoji: "💬" },
      { id: "topic_created_content", type: :topic_created, category_group: :content, min: 1, max: 2, reward: 15, emoji: "🎨" },
      { id: "post_created", type: :post_created, min: 1, max: 4, reward: 10, emoji: "✍️" },
      { id: "post_created_conv", type: :post_created, category_group: :conversation, min: 1, max: 4, reward: 10, emoji: "🗣️" },
      { id: "post_created_content", type: :post_created, category_group: :content, min: 1, max: 4, reward: 10, emoji: "🖼️" },
      { id: "chat_message_created", type: :chat_message_created, min: 1, max: 10, reward: 5, emoji: "📱" },
      { id: "character_grow", type: :character_grow, min: 1, max: 2, reward: 15, emoji: "📈" },
      { id: "character_shrink", type: :character_shrink, min: 1, max: 2, reward: 15, emoji: "📉" }
    ].freeze

    def self.ensure_quests_for(user)
      return [] if user.nil?

      existing = DiscourseSizeUserQuest.where(user_id: user.id)
      return existing if existing.any?

      # Generate new quests
      count = SiteSetting.discourse_size_daily_quests_count

      pool = QUESTS.select do |q|
        if q[:category_group] == :conversation
          SiteSetting.discourse_size_conversation_category_ids.present?
        elsif q[:category_group] == :content
          SiteSetting.discourse_size_content_category_ids.present?
        else
          true
        end
      end

      pool.sample(count).map do |q|
        DiscourseSizeUserQuest.create!(
          user_id: user.id,
          quest_id: q[:id],
          target_count: rand(q[:min]..q[:max]),
          reward: q[:reward]
        )
      end
    end

    def self.track_activity(user, type, options = {})
      return if user.nil?

      # Robustly identify user_id
      user_id = case user
                when Integer then user
                when String then user.to_i
                else (user.respond_to?(:id) ? user.id : nil)
                end
      return if user_id.nil? || user_id <= 0

      # Handle symbols/strings for type
      type = type.to_sym if type.respond_to?(:to_sym)

      quests = DiscourseSizeUserQuest.where(user_id: user_id, collected: false)

      quests.each do |quest|
        definition = QUESTS.find { |q| q[:id] == quest.quest_id }
        next unless definition

        # Match type (allow topic_created to match post_created as well)
        def_type = definition[:type].to_sym
        matched_type = (def_type == type) || (def_type == :post_created && type == :topic_created)
        next unless matched_type

        # Check category group if applicable
        if definition[:category_group]
          category_ids = case definition[:category_group].to_sym
                        when :conversation
                          SiteSetting.discourse_size_conversation_category_ids.to_s.split(",").map(&:to_i).reject(&:zero?)
                        when :content
                          SiteSetting.discourse_size_content_category_ids.to_s.split(",").map(&:to_i).reject(&:zero?)
                        else
                          []
                        end

          topic_category_id = options[:category_id].to_i
          matched = false

          if topic_category_id > 0
            # Check if category or any of its parents are in the list
            current_cat_id = topic_category_id
            max_depth = 10 # Prevent infinite loops
            while current_cat_id && max_depth > 0
              if category_ids.include?(current_cat_id)
                matched = true
                break
              end
              current_cat_id = Category.find_by(id: current_cat_id)&.parent_category_id
              max_depth -= 1
            end
          end

          next unless matched
        end

        # Atomic update progress
        if quest.current_count < quest.target_count
          DiscourseSizeUserQuest.where(id: quest.id).update_all("current_count = current_count + 1")
        end
      end
    end

    def self.collect_reward(user, quest_id)
      quest = DiscourseSizeUserQuest.find_by(user_id: user.id, id: quest_id, collected: false)
      return { success: false, error: "Quest not found or already collected." } unless quest&.completed?

      quest.update!(collected: true)

      ::DiscourseSize::PointsManager.add_points(
        user,
        quest.reward,
        source_type: "quest_reward",
        description: "Completed quest: #{quest.quest_id}"
      )

      { success: true, reward: quest.reward }
    end

    def self.collect_bonus(user)
      all_quests = DiscourseSizeUserQuest.where(user_id: user.id)
      return { success: false, error: "Not all quests completed or collected." } unless all_quests.any? && all_quests.all?(&:collected) && all_quests.count >= SiteSetting.discourse_size_daily_quests_count

      today = Date.today.to_s
      return { success: false, error: "Bonus already collected today." } if user.custom_fields["discourse_size_last_bonus_reward_date"] == today

      bonus = SiteSetting.discourse_size_extra_reward_amount
      ::DiscourseSize::PointsManager.add_points(
        user,
        bonus,
        source_type: "quest_bonus",
        description: "Completed all daily quests"
      )

      user.custom_fields["discourse_size_last_bonus_reward_date"] = today
      user.save_custom_fields(true)

      { success: true, reward: bonus }
    end

    def self.reroll(user)
      last_reroll = user.custom_fields["discourse_size_last_quest_reroll_date"]
      today = Date.today.to_s

      return { success: false, error: "Already rerolled today." } if last_reroll == today

      # Only reroll quests that are NOT finished (not collected AND not completed)
      to_reroll = DiscourseSizeUserQuest.where(user_id: user.id, collected: false).select { |q| !q.completed? }
      return { success: false, error: "No incomplete quests to reroll." } if to_reroll.empty?

      # Get IDs of quests to keep (collected or completed)
      kept_ids = DiscourseSizeUserQuest.where(user_id: user.id).select { |q| q.collected || q.completed? }.map(&:quest_id)

      # Generate new quests to replace incomplete ones
      available_pool = QUESTS.reject { |q| kept_ids.include?(q[:id]) }

      new_quests = available_pool.sample(to_reroll.count)

      DiscourseSizeUserQuest.transaction do
        DiscourseSizeUserQuest.where(id: to_reroll.map(&:id)).destroy_all
        new_quests.each do |q|
          DiscourseSizeUserQuest.create!(
            user_id: user.id,
            quest_id: q[:id],
            target_count: rand(q[:min]..q[:max]),
            reward: q[:reward]
          )
        end
        user.custom_fields["discourse_size_last_quest_reroll_date"] = today
        user.save_custom_fields(true)
      end

      { success: true, quests: ensure_quests_for(user) }
    end

    def self.can_get_new_quests?(user)
      return false if user.nil?
      
      quests = DiscourseSizeUserQuest.where(user_id: user.id)
      return true if quests.empty?

      # Can get new quests only on the next calendar day
      oldest_quest = quests.order(created_at: :asc).first
      oldest_quest.created_at < Time.zone.now.beginning_of_day
    end

    def self.get_new_quests(user)
      return { success: false, error: "Cannot get new quests today." } unless can_get_new_quests?(user)

      DiscourseSizeUserQuest.transaction do
        DiscourseSizeUserQuest.where(user_id: user.id).destroy_all
        user.custom_fields["discourse_size_last_quest_reroll_date"] = nil
        user.custom_fields["discourse_size_last_bonus_reward_date"] = nil
        user.save_custom_fields(true)
      end

      { success: true, quests: ensure_quests_for(user) }
    end

    def self.reset_quests(user)
      DiscourseSizeUserQuest.where(user_id: user.id).destroy_all
      user.custom_fields["discourse_size_last_quest_reroll_date"] = nil
      user.custom_fields["discourse_size_last_bonus_reward_date"] = nil
      user.save_custom_fields(true)

      ensure_quests_for(user)
    end
  end
end
