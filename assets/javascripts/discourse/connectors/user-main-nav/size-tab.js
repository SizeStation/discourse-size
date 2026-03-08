import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class SizeTab extends Component {
  @service siteSettings;

  get shouldDisplay() {
    return this.siteSettings.size_plugin_enabled;
  }
}
