import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

let activeDrags = 0;

function preventSelection(event) {
  event.preventDefault();
}

function clearSelection() {
  try {
    window.getSelection?.()?.removeAllRanges();
  } catch {
    // Ignore selection clearing failure
  }
}

function cleanupDragSelection() {
  document.body.classList.remove("discourse-size-dragging");
  window.removeEventListener("selectstart", preventSelection);
  window.removeEventListener("pointerup", handleGlobalPointerUp);
  window.removeEventListener("mouseup", handleGlobalPointerUp);
  window.removeEventListener("touchend", handleGlobalPointerUp);
  window.removeEventListener("touchcancel", handleGlobalPointerUp);
  clearSelection();
}

function handleGlobalPointerUp() {
  if (activeDrags > 0) {
    activeDrags = 0;
    cleanupDragSelection();
  }
}

function startPreventingTextSelection() {
  activeDrags++;
  if (activeDrags === 1) {
    document.body.classList.add("discourse-size-dragging");
    window.addEventListener("selectstart", preventSelection);
    window.addEventListener("pointerup", handleGlobalPointerUp);
    window.addEventListener("mouseup", handleGlobalPointerUp);
    window.addEventListener("touchend", handleGlobalPointerUp);
    window.addEventListener("touchcancel", handleGlobalPointerUp);
  }
  clearSelection();
}

function stopPreventingTextSelection() {
  activeDrags = Math.max(0, activeDrags - 1);
  if (activeDrags === 0) {
    cleanupDragSelection();
  }
}

export default class DiscourseSizeReorderableList extends Component {
  _isDragging = false;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._isDragging) {
      this._isDragging = false;
      stopPreventingTextSelection();
    }
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
        this._isDragging = true;
        startPreventingTextSelection();
        window.dispatchEvent(new CustomEvent("discourse-size:drag-start"));
      },
      onEnd: (evt) => {
        if (this._isDragging) {
          this._isDragging = false;
          stopPreventingTextSelection();
        }
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
