import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class DiscourseSizePreferences extends Component {
  @tracked
  measurementSystem =
    this.args.model.discourse_size_settings?.measurement_system || "imperial";

  get measurementOptions() {
    return [
      { id: "imperial", name: "Imperial (ft/in)" },
      { id: "metric", name: "Metric (cm/m)" },
    ];
  }

  @action
  async saveSettings() {
    try {
      await ajax("/size/shop/save_settings", {
        type: "POST",
        data: {
          measurement_system: this.measurementSystem,
        },
      });
    } catch (e) {
      console.error(e);
    }
  }

  @action
  onChangeMeasurement(value) {
    this.measurementSystem = value;
    this.saveSettings();
  }

  <template>
    <div class="control-group discourse-size-preferences">
      <label class="control-label">{{i18n
          "discourse_size.preferences.title"
        }}</label>
      <div class="controls">
        <div class="preference-row">
          <label class="control-label">{{i18n
              "discourse_size.preferences.measurement_system"
            }}</label>
          <ComboBox
            @content={{this.measurementOptions}}
            @value={{this.measurementSystem}}
            @onChange={{this.onChangeMeasurement}}
          />
        </div>
      </div>
    </div>
  </template>
}
