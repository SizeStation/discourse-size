import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import DiscourseSizeCreateRoleplay from "./discourse-size-create-roleplay";

export default class DiscourseSizeRoleplaysModal extends Component {
  @service router;
  @service modal;
  
  @tracked roleplays = [];
  @tracked loading = true;
  @tracked searchTerm = "";

  constructor() {
    super(...arguments);
    this.fetchRoleplays();
  }

  async fetchRoleplays() {
    try {
      const result = await ajax("/size/roleplays");
      this.roleplays = result.roleplays;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  get filteredRoleplays() {
    if (!this.searchTerm) return this.roleplays;
    const term = this.searchTerm.toLowerCase();
    return this.roleplays.filter(rp => rp.name.toLowerCase().includes(term));
  }

  @action
  openRoleplay(roleplay) {
    this.args.closeModal();
    this.router.transitionTo("size-roleplay", roleplay.uuid);
  }

  @action
  createRoleplay() {
    this.args.closeModal();
    this.modal.show(DiscourseSizeCreateRoleplay, {
      model: {
        onCreate: (roleplay) => {
          this.router.transitionTo("size-roleplay", roleplay.uuid);
        }
      }
    });
  }
}
