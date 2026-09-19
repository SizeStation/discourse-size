import Helper from "@ember/component/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { formatSize } from "../lib/size-formatter";

export default class FormatSize extends Helper {
  @service currentUser;

  compute([size, system], { plainText = false } = {}) {
    const defaultSystem =
      this.currentUser?.discourse_size_settings?.measurement_system ||
      "imperial";
    const formatted = formatSize(size, system || defaultSystem);
    if (!plainText && (formatted === "∞" || formatted === "-∞")) {
      const label = formatted === "-∞" ? "-infinity" : "infinity";
      return htmlSafe(
        `<span class="ds-infinity-symbol" aria-label="${label}">${formatted}</span>`
      );
    }
    return formatted;
  }
}
