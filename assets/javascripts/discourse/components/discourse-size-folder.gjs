import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import icon from "discourse/helpers/d-icon";

export default class DiscourseSizeFolder extends Component {
  @tracked collapsed = true;
  @tracked isDragOver = false;
  @tracked _autoOpened = false;

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("discourse-size:drag-end", this.onDragEnd);
  }

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

  <template>
    <div
      class="discourse-size-folder
        {{if this.collapsed 'collapsed'}}
        {{if this.isEmpty 'is-empty'}}
        {{if this.isDragOver 'is-drag-over'}}"
      {{on "dragenter" this.handleDragEnter}}
      {{on "dragleave" this.handleDragLeave}}
      {{didInsert this.setupEvents}}
      data-folder-id={{@folder.id}}
    >
      {{! template-lint-disable no-invalid-interactive }}
      <div class="folder-header" {{on "click" this.toggle}}>
        <div
          class="folder-title"
          style={{if @folder.hex_color (concat "color: " @folder.hex_color)}}
        >
          {{icon (if this.collapsed "chevron-right" "chevron-down")}}
          <span class="folder-name">{{@folder.name}}
            ({{@characterCount}})</span>
        </div>

        {{#if @isCurrentUser}}
          <div class="folder-actions">
            <button
              type="button"
              class="btn btn-flat edit-folder-btn"
              {{on "click" this.edit}}
            >
              Edit
            </button>
            <div class="folder-drag-handle">
              {{icon "bars"}}
            </div>
          </div>
        {{/if}}
      </div>

      <div class="folder-contents" data-folder-id={{@folder.id}}>
        {{yield}}
      </div>
    </div>
  </template>
}
