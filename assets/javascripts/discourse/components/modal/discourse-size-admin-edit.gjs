import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { getBestUnit, UNITS } from "../../lib/size-formatter";

export default class DiscourseSizeAdminEdit extends Component {
  @tracked originalCurrentSize = 0;
  @tracked isSaving = false;
  @tracked sizeUnit = "cm";
  @tracked displaySize = 0;

  constructor() {
    super(...arguments);
    const char = this.args?.model?.character || {};
    this.currentSize = char.current_size;
    this.originalCurrentSize = char.current_size;
    const unit = getBestUnit(this.currentSize);
    this.sizeUnit = unit.id;
    this.displaySize = parseFloat(
      (this.currentSize / unit.factor).toPrecision(5)
    );
  }

  get units() {
    return UNITS;
  }

  @action
  onUnitChange(event) {
    this.sizeUnit = event?.target ? event.target.value : event;
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
      alert(
        e.jqXHR?.responseJSON?.errors?.join(", ") ||
          "Error syncing character with history"
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
      alert(
        e.jqXHR?.responseJSON?.errors?.join(", ") ||
          "Error saving character as admin"
      );
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <DModal
      @title="Admin Edit Character"
      @closeModal={{@closeModal}}
      class="discourse-size-edit-character-modal"
    >
      <:body>
        <div class="control-group">
          <label>Override Current Size</label>
          <span class="instructions">Directly teleport the character to this
            size.</span>
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
          <span class="instructions">Teleport to the final size calculated from
            the activity log.</span>
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
