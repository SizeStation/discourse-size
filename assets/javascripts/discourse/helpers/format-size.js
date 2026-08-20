import Helper from "@ember/component/helper";
import { service } from "@ember/service";
import { formatSize } from "../lib/size-formatter";

export default class FormatSize extends Helper {
  @service currentUser;

  compute([size, system]) {
    const defaultSystem =
      this.currentUser?.discourse_size_settings?.measurement_system ||
      "imperial";
    return formatSize(size, system || defaultSystem);
  }
}
