import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class DiscourseSizeDailyQuests extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked loading = true;
  @tracked quests = [];
  @tracked dailyRewardStatus = "available";
  @tracked canReroll = false;
  @tracked bonusCollected = false;
  @tracked extraRewardAmount = 0;
  @tracked collectingDaily = false;
  @tracked collectingQuest = false;
  @tracked collectingBonus = false;
  @tracked rerolling = false;

  constructor() {
    super(...arguments);
    this.loadQuests();
  }

  async loadQuests() {
    try {
      const response = await ajax("/size/quests");
      this.quests = response.quests;
      this.dailyRewardStatus = response.daily_reward_status;
      this.canReroll = response.can_reroll;
      this.extraRewardAmount = response.extra_reward_amount;
      this.bonusCollected = response.bonus_collected;
      this.loading = false;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  get allQuestsCompleted() {
    return this.quests.length > 0 && this.quests.every((q) => q.collected);
  }

  @action
  async collectDailyReward() {
    this.collectingDaily = true;
    try {
      const response = await ajax("/size/shop/claim_reward", { type: "POST" });
      if (response.success) {
        this.dailyRewardStatus = "collected";
        this.currentUser.set("discourse_size_points", response.current_points);
        this.loadQuests();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.collectingDaily = false;
    }
  }

  @action
  async collectQuest(quest) {
    this.collectingQuest = true;
    try {
      const response = await ajax("/size/quests/collect", {
        type: "POST",
        data: { quest_id: quest.id },
      });
      if (response.success) {
        this.currentUser.set("discourse_size_points", response.current_points);
        await this.loadQuests();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.collectingQuest = false;
    }
  }

  @action
  async collectBonusReward() {
    this.collectingBonus = true;
    try {
      const response = await ajax("/size/quests/collect_bonus", { type: "POST" });
      if (response.success) {
        this.bonusCollected = true;
        this.currentUser.set("discourse_size_points", response.current_points);
        this.loadQuests();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.collectingBonus = false;
    }
  }

  @action
  async rerollQuests() {
    this.rerolling = true;
    try {
      const response = await ajax("/size/quests/reroll", { type: "POST" });
      if (response?.success) {
        this.quests = response.quests;
        this.canReroll = false;
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.rerolling = false;
    }
  }

  @action
  async adminResetQuests() {
    try {
      await ajax("/size/admin/reset_quests", { type: "POST" });
      this.loadQuests();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  getQuestName(quest) {
    return I18n.t(`discourse_size.quests.names.${quest.quest_id}`, { count: quest.target_count });
  }

  getQuestProgress(quest) {
    return Math.min(100, (quest.current_count / quest.target_count) * 100);
  }

  get inviteReward() {
    return this.siteSettings.discourse_size_points_per_invite;
  }

  get invitedReward() {
    return this.siteSettings.discourse_size_points_per_invited;
  }
}
