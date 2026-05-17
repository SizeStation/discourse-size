import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class DiscourseSizeTriggerHelp extends Component {
  @action
  close() {
    this.args.closeModal();
  }
}
