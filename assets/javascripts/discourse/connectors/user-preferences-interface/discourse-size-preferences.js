import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class DiscourseSizePreferences extends Component {
  @tracked measurementSystem =
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

}
