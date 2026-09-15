import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { eq, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

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
  @tracked canGetNewQuests = false;
  @tracked nextRerollAt = null;
  @tracked rerollTimerText = "";
  @tracked gettingNewQuests = false;

  _timer = null;

  constructor() {
    super(...arguments);
    this.loadQuests();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._timer) {
      clearInterval(this._timer);
    }
  }

  async loadQuests() {
    try {
      const response = await ajax("/size/quests");
      this.quests = response.quests;
      this.dailyRewardStatus = response.daily_reward_status;
      this.canReroll = response.can_reroll;
      this.canGetNewQuests = response.can_get_new_quests;
      this.nextRerollAt = response.next_reroll_at;
      this.extraRewardAmount = response.extra_reward_amount;
      this.bonusCollected = response.bonus_collected;
      this.loading = false;

      this.startRerollTimer();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  startRerollTimer() {
    if (this._timer) {
      clearInterval(this._timer);
    }

    if (this.canReroll || !this.nextRerollAt) {
      this.rerollTimerText = "";
      return;
    }

    const updateTimer = () => {
      const now = new Date();
      const target = new Date(this.nextRerollAt);
      const diff = target - now;

      if (diff <= 0) {
        this.rerollTimerText = "";
        this.canReroll = true;
        clearInterval(this._timer);
        return;
      }

      const hours = Math.floor(diff / 3600000);
      const minutes = Math.floor((diff % 3600000) / 60000);
      const seconds = Math.floor((diff % 60000) / 1000);

      this.rerollTimerText = i18n("js.discourse_size.quests.next_reroll_in", {
        time: `${hours}h ${minutes}m ${seconds}s`,
      });
    };

    updateTimer();
    this._timer = setInterval(updateTimer, 1000);
  }

  get allQuestsCompleted() {
    return this.quests.length > 0 && this.quests.every((q) => q.collected);
  }

  @action
  async collectDailyReward() {
    if (this.collectingDaily) {
      return;
    }
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
    if (this.collectingQuest) {
      return;
    }
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
    if (this.collectingBonus) {
      return;
    }
    this.collectingBonus = true;
    try {
      const response = await ajax("/size/quests/collect_bonus", {
        type: "POST",
      });
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
        this.startRerollTimer();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.rerolling = false;
    }
  }

  @action
  async getNewQuests() {
    this.gettingNewQuests = true;
    try {
      const response = await ajax("/size/quests/get_new", { type: "POST" });
      if (response?.success) {
        this.quests = response.quests;
        this.canGetNewQuests = false;
        this.canReroll = true;
        this.startRerollTimer();
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.gettingNewQuests = false;
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
    return i18n(`discourse_size.quests.names.${quest.quest_id}`, {
      count: quest.target_count,
    });
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

  <template>
    <DModal
      @title={{i18n "discourse_size.quests.modal_title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-daily-quests-modal"
    >
      <:body>
        <div class="quests-container">
          <h3>{{i18n "discourse_size.admin.daily_reward_section"}}</h3>
          <div class="daily-reward-section">
            {{#if (eq this.dailyRewardStatus "available")}}
              <DButton
                @label="discourse_size.quests.collect_daily_reward_10"
                @action={{this.collectDailyReward}}
                @disabled={{this.collectingDaily}}
                class="btn-primary btn-large daily-collect-btn"
              />
            {{else}}
              <DButton
                @label="discourse_size.quests.come_back_tomorrow"
                @disabled={{true}}
                class="btn-default btn-large daily-collect-btn"
              />
            {{/if}}
          </div>
        </div>

        <div class="quests-container">
          <h3>{{i18n "discourse_size.quests.daily_quests"}}</h3>
          <div class="quests-list">
            {{#each this.quests as |quest|}}
              <div class="quest-item {{if quest.collected 'collected'}}">
                <div class="quest-emoji">{{quest.emoji}}</div>
                <div class="quest-info">
                  <span class="quest-name">{{this.getQuestName quest}}</span>
                  <div class="quest-progress-wrapper">
                    <div class="quest-progress-bar">
                      <div
                        class="progress-fill"
                        style={{trustHTML
                          (concat "width: " (this.getQuestProgress quest) "%")
                        }}
                      ></div>
                    </div>
                    <span class="progress-text">{{quest.current_count}}
                      /
                      {{quest.target_count}}</span>
                  </div>
                </div>
                <div class="quest-actions">
                  <span class="quest-reward">{{i18n
                      "discourse_size.coins"
                      count=quest.reward
                    }}</span>
                  <DButton
                    @label="discourse_size.quests.collect"
                    @action={{fn this.collectQuest quest}}
                    @disabled={{or
                      (not quest.completed)
                      quest.collected
                      this.collectingQuest
                    }}
                    class={{if quest.completed "btn-primary" "btn-default"}}
                  />
                </div>
              </div>
            {{/each}}
          </div>

          <div class="quests-footer">
            {{#if this.canGetNewQuests}}
              <DButton
                @label="discourse_size.quests.get_new_quests"
                @action={{this.getNewQuests}}
                @disabled={{this.gettingNewQuests}}
                class="btn-primary reroll-btn"
              />
            {{else}}
              {{#if this.allQuestsCompleted}}
                <DButton
                  @label="discourse_size.quests.come_back_tomorrow"
                  @disabled={{true}}
                  class="btn-default reroll-btn"
                />
              {{else}}
                {{#if this.canReroll}}
                  <DButton
                    @label="discourse_size.quests.reroll_quests"
                    @action={{this.rerollQuests}}
                    @disabled={{this.rerolling}}
                    class="btn-default reroll-btn"
                  />
                {{/if}}
              {{/if}}
            {{/if}}

            {{#if this.rerollTimerText}}
              <span class="reroll-timer">{{this.rerollTimerText}}</span>
            {{/if}}
            {{#if this.currentUser.admin}}
              <DButton
                @icon="wrench"
                @label="discourse_size.quests.admin_reset_quests"
                @action={{this.adminResetQuests}}
                class="btn-danger reroll-btn admin-only"
              />
            {{/if}}
          </div>

          <div
            class="bonus-quest-section {{if this.bonusCollected 'collected'}}"
          >
            <div class="bonus-quest-info">
              <span class="bonus-quest-title">{{i18n
                  "discourse_size.quests.bonus_reward"
                }}</span>
              <p class="bonus-quest-description">Complete all daily quests to
                earn an extra reward!</p>
            </div>
            <div class="bonus-quest-action">
              <DButton
                @action={{this.collectBonusReward}}
                @disabled={{or
                  (not this.allQuestsCompleted)
                  this.bonusCollected
                  this.collectingBonus
                }}
                @labelOptions={{hash count=this.extraRewardAmount}}
                class={{if this.allQuestsCompleted "btn-primary" "btn-default"}}
              >
                {{i18n
                  "discourse_size.quests.collect_bonus"
                  count=this.extraRewardAmount
                }}
              </DButton>
            </div>
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
