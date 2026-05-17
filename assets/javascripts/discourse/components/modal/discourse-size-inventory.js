import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";

export default class DiscourseSizeInventory extends Component {
  @service currentUser;
  @tracked inventory = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.fetchInventory();
  }

  async fetchInventory() {
    try {
      const userId = this.args.model.giftingMode
        ? this.currentUser.id
        : this.args.model.user.id;

      const result = await ajax("/size/inventory", {
        data: { user_id: userId },
      });
      this.inventory = result.inventory;
    } catch (e) {
      // Error
    } finally {
      this.loading = false;
    }
  }

  useItem(item) {
    if (this.args.model.characterId) {
      this.args.model.onSelect?.(item);
    }
  }

  get isClickable() {
    return !!this.args.model.onSelect;
  }

  @action
  selectItem(item) {
    if (this.isClickable) {
      this.args.model.onSelect?.(item);
    }
  }
}
