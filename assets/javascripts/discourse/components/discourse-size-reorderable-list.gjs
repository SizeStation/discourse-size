import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

export default class DiscourseSizeReorderableList extends Component {
  willDestroy() {
    super.willDestroy(...arguments);
    this.sortable?.destroy();
  }

  @action
  onInsert(element) {
    if (!this.args.enabled) {
      return;
    }

    if (!window.Sortable) {
      const existingScript = document.querySelector(
        'script[src*="sortablejs"]'
      );
      if (existingScript) {
        existingScript.addEventListener("load", () =>
          this.initSortable(element)
        );
        return;
      }

      // Load Sortable if not present
      const script = document.createElement("script");
      script.src =
        "https://cdn.jsdelivr.net/npm/sortablejs@1.15.0/Sortable.min.js";
      script.onload = () => this.initSortable(element);
      document.head.appendChild(script);
    } else {
      this.initSortable(element);
    }
  }

  initSortable(element) {
    this.sortable = window.Sortable.create(element, {
      handle: this.args.handle || ".drag-handle",
      group: {
        name: this.args.group || "reorderable",
        pull: true,
        put: true,
      },
      animation: 200,
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      forceFallback: true,
      fallbackClass: "sortable-fallback",
      fallbackOnBody: true,
      scroll: true,
      scrollSensitivity: 100,
      scrollSpeed: 20,
      onStart: () => {
        window.dispatchEvent(new CustomEvent("discourse-size:drag-start"));
      },
      onEnd: (evt) => {
        window.dispatchEvent(new CustomEvent("discourse-size:drag-end"));
        this.args.onReorder?.(evt);
      },
    });
  }

  <template>
    <div
      class="discourse-size-reorderable-list"
      {{didInsert this.onInsert}}
      ...attributes
    >
      {{yield}}
    </div>
  </template>
}
