import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { later, cancel } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class UserSizeController extends Controller {
  @service dialog;
  @service siteSettings;
  @service currentUser;

  @tracked compareUsername = "";
  @tracked compareTargets = [];
  @tracked spendAmount = 1;
  @tracked editDefaultSize = 170.0;

  @tracked adminOverridePoints = this.model.size_stat_points;
  @tracked adminOverrideTargetSize = this.model.size_stat_target_size;
  @tracked adminOverrideGrowthRate = this.model.size_stat_growth_rate;

  @tracked liveSize = 0;
  _ticker = null;

  constructor() {
    super(...arguments);
    this.startTicker();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._ticker) {
      cancel(this._ticker);
    }
  }

  startTicker() {
    this._tick();
  }

  @action
  _tick() {
    if (this.model && this.model.size_stat_base_size !== undefined) {
      let base = parseFloat(this.model.size_stat_base_size);
      let target = parseFloat(this.model.size_stat_target_size);
      
      if (base === target) {
        this.liveSize = target;
      } else {
        let rate = parseFloat(this.model.size_stat_growth_rate) || 0;
        let updatedAt = new Date(this.model.size_stat_updated_at);
        let now = new Date();
        
        let daysLapsed = (now - updatedAt) / (1000 * 60 * 60 * 24);
        let changeAmount = daysLapsed * (base * (Math.abs(rate) / 100.0));
        let totalDiff = Math.abs(target - base);
        
        if (changeAmount >= totalDiff) {
          this.liveSize = target;
        } else {
          this.liveSize = target > base ? base + changeAmount : base - changeAmount;
        }
      }
    }
    
    // run every 50ms for smooth UI updates
    this._ticker = later(this, this._tick, 50);
  }

  get isCurrentUser() {
    return this.currentUser && this.model.id === this.currentUser.id;
  }

  get myPoints() {
    // If we are looking at our own profile, use model points, otherwise use currentUser (if serialized)
    return this.isCurrentUser ? this.model.size_stat_points : (this.currentUser?.size_stat_points || 0);
  }

  get remainingPoints() {
    return this.myPoints - this.spendAmount;
  }

  get growPreviewAmount() {
    let percent = this.spendAmount * this.siteSettings.size_growth_percent_per_point;
    let target = this.model.size_stat_target_size;
    let newTarget = target * (1.0 + (percent / 100.0));
    return newTarget - target;
  }

  get shrinkPreviewAmount() {
    let percent = this.spendAmount * this.siteSettings.size_growth_percent_per_point;
    let target = this.model.size_stat_target_size;
    let newTarget = Math.max(target * (1.0 - (percent / 100.0)), 0.000001);
    return target - newTarget;
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
        target_username: this.model.username,
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
    if (!this.compareUsername || this.compareUsername.length === 0) return;

    let compareNames = typeof this.compareUsername === "string" 
      ? this.compareUsername.split(",").map((s) => s.trim()) 
      : this.compareUsername;

    let targets = [this.model.username, ...compareNames];

    ajax("/discourse-size/compare", {
      type: "GET",
      data: { targets },
    })
      .then((res) => {
        this.compareTargets = res.targets;
      })
      .catch(popupAjaxError);
  }

  @action
  applyAdminOverride() {
    ajax("/discourse-size/admin/override", {
      type: "POST",
      data: {
        target_username: this.model.username,
        points: this.adminOverridePoints,
        target_size: this.adminOverrideTargetSize,
        growth_rate: this.adminOverrideGrowthRate,
      },
    })
      .then(() => {
        this.dialog.alert("Admin overrides applied successfully!");
        window.location.reload();
      })
      .catch(popupAjaxError);
  }

  @action
  applyDefaultSize() {
    ajax("/discourse-size/default_size", {
      type: "PUT",
      data: { default_size: this.editDefaultSize },
    })
      .then(() => {
        this.dialog.alert("Default size updated successfully!");
        window.location.reload();
      })
      .catch(popupAjaxError);
  }

  @action
  resetSize() {
    this.dialog.yesNoConfirm({
      message: "Are you sure you want to reset your size back to your default? You will NOT regain any spent points.",
      didConfirm: () => {
        ajax("/discourse-size/reset_size", { type: "POST" })
          .then(() => {
            this.dialog.alert("Size has been reset!");
            window.location.reload();
          })
          .catch(popupAjaxError);
      }
    });
  }
}
