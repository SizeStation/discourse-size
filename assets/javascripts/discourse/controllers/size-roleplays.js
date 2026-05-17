import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import DiscourseSizeCreateRoleplay from "../components/modal/discourse-size-create-roleplay";

export default class SizeRoleplaysController extends Controller {
  @service modal;
  @tracked roleplays = [];

  @action
  createRoleplay() {
    this.modal.show(DiscourseSizeCreateRoleplay, {
      model: {
        onSave: (newRp) => {
          this.roleplays = [newRp, ...this.roleplays];
        },
      },
    });
  }
}
