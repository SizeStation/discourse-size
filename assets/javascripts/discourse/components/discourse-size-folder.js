import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class DiscourseSizeFolder extends Component {
  @tracked collapsed = true;
  @tracked _autoOpened = false;
  @tracked isDragOver = false;

  get isEmpty() {
    return (this.args.characterCount || 0) === 0;
  }

  @action
  toggle() {
    this.collapsed = !this.collapsed;
    this._autoOpened = false;
  }

  @action
  edit(event) {
    event.stopPropagation();
    this.args.onEdit?.();
  }

  @action
  handleDragEnter() {
    this.isDragOver = true;
    if (this.collapsed) {
      this.collapsed = false;
      this._autoOpened = true;
    }
  }

  @action
  handleDragLeave() {
    this.isDragOver = false;
  }

  @action
  onDragEnd() {
    if (this._autoOpened) {
      // Give it a moment for Sortable to finish moving the item
      setTimeout(() => {
        if (this._autoOpened) {
          // Check if any item was actually dropped into our list
          const list = document.querySelector(
            `.discourse-size-folder[data-folder-id="${this.args.folder.id}"] .discourse-size-reorderable-list`
          );
          const hasItems =
            list && list.querySelectorAll(".reorderable-item").length > 0;

          if (!hasItems) {
            this.collapsed = true;
          }
          this._autoOpened = false;
          this.isDragOver = false;
        }
      }, 200);
    } else {
      this.isDragOver = false;
    }
  }

  @action
  setupEvents() {
    window.addEventListener("discourse-size:drag-end", this.onDragEnd);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("discourse-size:drag-end", this.onDragEnd);
  }
}
