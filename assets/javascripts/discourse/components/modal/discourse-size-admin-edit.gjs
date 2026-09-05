import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { getBestUnit, UNITS } from "../../lib/size-formatter";

export default class DiscourseSizeAdminEdit extends Component {
  @service currentUser;
  @service dialog;

  @tracked originalCurrentSize = 0;
  @tracked isSaving = false;
  @tracked sizeUnit = "cm";
  @tracked displaySize = 0;

  constructor() {
    super(...arguments);
    const char = this.args?.model?.character || {};
    this.currentSize = char.current_size;
    this.originalCurrentSize = char.current_size;
    const unit = getBestUnit(this.currentSize, this.preferredSystem);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat(
      (this.currentSize / unit.factor).toPrecision(5)
    );
  }

  get preferredSystem() {
    return (
      this.currentUser?.discourse_size_settings?.measurement_system ||
      this.args?.model?.character?.measurement_system ||
      "imperial"
    );
  }

  get units() {
    return UNITS;
  }

  @action
  onUnitChange(event) {
    const newUnitId = event?.target ? event.target.value : event;
    const oldUnit = UNITS.find((u) => u.id === this.sizeUnit) || { factor: 1 };
    const newUnit = UNITS.find((u) => u.id === newUnitId) || { factor: 1 };
    const parsed = parseFloat(this.displaySize);
    if (!isNaN(parsed)) {
      const currentCm = parsed * oldUnit.factor;
      this.displaySize = parseFloat(
        (currentCm / newUnit.factor).toPrecision(5)
      );
    }
    this.sizeUnit = newUnitId;
  }

  @action
  async syncWithHistory() {
    this.isSaving = true;
    try {
      await ajax(
        `/size/admin/characters/${this.args?.model?.character?.id}/sync`,
        {
          type: "POST",
        }
      );
      this.args?.model?.onSave?.();
      this.args?.closeModal?.();
    } catch (e) {
      this.dialog.alert(
        e.jqXHR?.responseJSON?.errors?.join(", ") ||
          i18n("discourse_size.admin.error_syncing")
      );
    } finally {
      this.isSaving = false;
    }
  }

  @action
  async save() {
    this.isSaving = true;

    const data = {};

    const unit = UNITS.find((u) => u.id === this.sizeUnit) || { factor: 1 };
    const currentSizeInCm = parseFloat(this.displaySize) * unit.factor;

    if (
      Math.abs(currentSizeInCm - parseFloat(this.originalCurrentSize)) > 0.0001
    ) {
      data.current_size = currentSizeInCm;
    }

    try {
      await ajax(`/size/admin/characters/${this.args?.model?.character?.id}`, {
        type: "PUT",
        data,
      });
      this.args?.model?.onSave?.();
      this.args?.closeModal?.();
    } catch (e) {
      this.dialog.alert(
        e.jqXHR?.responseJSON?.errors?.join(", ") ||
          i18n("discourse_size.admin.error_saving")
      );
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_size.admin.edit_title"}}
      @closeModal={{@closeModal}}
      class="discourse-size-edit-character-modal"
    >
      <:body>
        <div class="control-group">
          <label>{{i18n "discourse_size.admin.override_current_size"}}</label>
          <span class="instructions">{{i18n
              "discourse_size.admin.override_current_size_instructions"
            }}</span>
          <div class="size-input-wrapper">
            <Input @type="number" @value={{this.displaySize}} step="0.0001" />
            <select
              class="size-unit-selector"
              {{on "change" this.onUnitChange}}
            >
              {{#each this.units as |unit|}}
                <option value={{unit.id}} selected={{eq this.sizeUnit unit.id}}>
                  {{unit.name}}
                </option>
              {{/each}}
            </select>
          </div>
        </div>
        <div class="control-group">
          <DButton
            @action={{this.syncWithHistory}}
            @label="discourse_size.admin.sync_with_history"
            @disabled={{this.isSaving}}
            class="btn-default"
          />
          <span class="instructions">{{i18n
              "discourse_size.admin.sync_with_history_instructions"
            }}</span>
        </div>

        <hr />

      </:body>
      <:footer>
        <DButton
          @action={{this.save}}
          @label="save"
          @disabled={{this.isSaving}}
          class="btn-primary"
        />
        <DButton @action={{@closeModal}} @label="cancel" class="btn-default" />
      </:footer>
    </DModal>
  </template>
}
