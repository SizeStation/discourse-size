# frozen_string_literal: true

module DiscourseSize
  class QuestsController < ::ApplicationController
    requires_plugin DiscourseSize::PLUGIN_NAME
    before_action :ensure_logged_in

    def index
      quests = QuestManager.ensure_quests_for(current_user)
      
      render json: {
        quests: serialize_data(quests, DiscourseSizeUserQuestSerializer),
        daily_reward_status: current_user.custom_fields["discourse_size_last_daily_reward_date"] == Date.today.to_s ? "collected" : "available",
        can_reroll: current_user.custom_fields["discourse_size_last_quest_reroll_date"] != Date.today.to_s,
        extra_reward_amount: SiteSetting.discourse_size_extra_reward_amount,
        bonus_collected: current_user.custom_fields["discourse_size_last_bonus_reward_date"] == Date.today.to_s
      }
    end

    def collect
      quest_id = params[:quest_id]
      result = QuestManager.collect_reward(current_user, quest_id)
      
      if result[:success]
        render json: {
          success: true,
          reward: result[:reward],
          current_points: PointsManager.get_points(current_user)
        }
      else
        render json: { failed: true, message: result[:error] }, status: :unprocessable_content
      end
    end

    def collect_bonus
      result = QuestManager.collect_bonus(current_user)
      
      if result[:success]
        render json: {
          success: true,
          reward: result[:reward],
          current_points: PointsManager.get_points(current_user)
        }
      else
        render json: { failed: true, message: result[:error] }, status: :unprocessable_content
      end
    end

    def reroll
      result = QuestManager.reroll(current_user)
      
      if result[:success]
        render json: {
          success: true,
          quests: serialize_data(result[:quests], DiscourseSizeUserQuestSerializer),
        }
      else
        render json: { success: false, failed: true, message: result[:error] }, status: :unprocessable_content
      end
    end
  end
end
