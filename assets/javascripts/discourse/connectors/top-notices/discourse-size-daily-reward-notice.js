import Component from "@ember/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizeDailyRewardNotice extends Component {
  @service currentUser;
  @service router;
  dismissed = false;

  get shouldShow() {
    return (
      !this.dismissed && this.currentUser?.discourse_size_can_claim_daily_reward
    );
  }

  @action
  async dismissNotice() {
    this.set("dismissed", true);
    try {
      await ajax("/size/shop/dismiss_reward_notice", { type: "POST" });
    } catch (e) {
      // Failed to save dismissal, but we already hid it locally
    }
  }
}
