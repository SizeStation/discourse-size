import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class UserSizeController extends Controller {
  @service dialog;
  
  @tracked compareUsername = "";
  @tracked compareTargets = [];
  @tracked spendAmount = 1;
  @tracked spendTargetUsername = "";

  get isCurrentUser() {
    return this.currentUser && this.model.id === this.currentUser.id;
  }

  @action
  savePreferences() {
    ajax("/discourse-size/preferences", {
      type: "PUT",
      data: {
        measurement_system: this.model.size_stat_measurement_system,
        consent_grow: this.model.size_stat_consent_grow,
        consent_shrink: this.model.size_stat_consent_shrink,
        ranking_public: this.model.size_stat_ranking_public,
      },
    })
      .then(() => {
        this.dialog.alert("Preferences saved successfully!");
      })
      .catch(popupAjaxError);
  }

  @action
  spendPoints(actionType) {
    if (this.spendAmount <= 0) return;

    ajax("/discourse-size/spend", {
      type: "POST",
      data: {
        action_type: actionType,
        points: this.spendAmount,
        target_username: this.spendTargetUsername || this.model.username,
      },
    })
      .then((res) => {
        this.dialog.alert(`Success! New target size is ${res.new_target} cm.`);
        // Note: For a real app, we'd want to reload the model from the server here to get new current_size immediately
        window.location.reload(); 
      })
      .catch(popupAjaxError);
  }

  @action
  uploadDone(upload) {
    ajax("/discourse-size/picture", {
      type: "POST",
      data: { upload_id: upload.id },
    })
      .then(() => {
        this.dialog.alert("Character picture updated!");
        this.set("model.size_stat_character_upload_id", upload.id);
      })
      .catch(popupAjaxError);
  }

  @action
  loadComparison() {
    if (!this.compareUsername) return;
    
    let targets = [this.model.username, this.compareUsername];
    
    ajax("/discourse-size/compare", {
      type: "GET",
      data: { targets },
    })
      .then((res) => {
        this.compareTargets = res.targets;
      })
      .catch(popupAjaxError);
  }
}
