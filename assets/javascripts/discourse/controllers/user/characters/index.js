import Controller from "@ember/controller";
import { action, computed, set } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

import DiscourseSizeEditCharacter from "../../../components/modal/discourse-size-edit-character";
import DiscourseSizeEditFolder from "../../../components/modal/discourse-size-edit-folder";
import DiscourseSizePointHistory from "../../../components/modal/discourse-size-point-history";

import DiscourseSizeAdminUser from "../../../components/modal/discourse-size-admin-user";
import DiscourseSizeInventory from "../../../components/modal/discourse-size-inventory";
import I18n from "I18n";

export default class UserCharactersIndexController extends Controller {
  @service currentUser;
  @service modal;
  @service siteSettings;

  get isCurrentUser() {
    return this.currentUser && this.currentUser.id === this.user?.id;
  }

  @action
  showPointHistory() {
    this.modal.show(DiscourseSizePointHistory, {
      model: {
        user: this.user,
        onSave: () => {
          this.refreshCharacters();
        },
      },
    });
  }

  @action
  showAdminModal() {
    this.modal.show(DiscourseSizeAdminUser, {
      model: {
        user: this.user,
        onSave: () => {
          this.refreshCharacters();
        },
      },
    });
  }

  @action
  openGiftingModal() {
    this.modal.show(DiscourseSizeInventory, {
      model: {
        user: this.user,
        giftingMode: true,
        onSelect: (item) => {
          this.giftItemFlow(item);
        },
      },
    });
  }

  async giftItemFlow(item) {
    let username = this.user?.username;
    if (!username || this.isCurrentUser) {
      username = prompt(I18n.t("discourse_size.inventory.gift_prompt"));
    }

    if (!username) {
      return;
    }

    if (
      !confirm(
        I18n.t("discourse_size.inventory.gift_confirm", {
          item: item.details.name,
          user: username,
        })
      )
    ) {
      return;
    }

    try {
      await ajax("/size/inventory/gift", {
        type: "POST",
        data: {
          inventory_item_id: item.id,
          username,
        },
      });
      alert(I18n.t("discourse_size.inventory.gift_success", { username }));
      this.modal.hide();
    } catch (e) {
      alert(e.jqXHR?.responseJSON?.message || "Error gifting item");
    }
  }

  @action
  createNewCharacter() {
    this.modal.show(DiscourseSizeEditCharacter, {
      model: {
        character: {},
        isNew: true,
        onSave: (result) => {
          this.refreshCharacters(result);
        },
      },
    });
  }

  @action
  async deleteCharacter(character) {
    if (confirm("Are you sure you want to delete this character?")) {
      try {
        await ajax(`/size/characters/${character.id}`, { type: "DELETE" });
        this.refreshCharacters();
      } catch (e) {
        alert("Error deleting character");
      }
    }
  }

  @action
  updateCharacter(character) {
    this.modal.show(DiscourseSizeEditCharacter, {
      model: {
        character: Object.assign({}, character),
        isNew: false,
        onSave: (result) => {
          this.refreshCharacters(result);
        },
        onDelete: () => {
          this.refreshCharacters();
        },
        onSetMain: () => {
          this.refreshCharacters();
        },
      },
    });
  }

  @action
  createNewFolder() {
    this.modal.show(DiscourseSizeEditFolder, {
      model: {
        isNew: true,
        onSave: () => {
          this.refreshCharacters();
        },
      },
    });
  }

  @action
  editFolder(folder) {
    this.modal.show(DiscourseSizeEditFolder, {
      model: {
        folder: Object.assign({}, folder),
        isNew: false,
        onSave: () => {
          this.refreshCharacters();
        },
      },
    });
  }

  @action
  async refreshCharacters(result) {
    // Update points if returned
    if (result && result.points !== undefined) {
      this.set("user.discourse_size_points", result.points);
      if (this.isCurrentUser) {
        this.currentUser.set("discourse_size_points", result.points);
      }
    }


    try {
      const res = await ajax(`/size/characters?user_id=${this.user.id}`);
      this.setProperties({
        characters: res.characters || [],
        folders: res.folders || [],
      });
      this.notifyPropertyChange("characters");
      this.notifyPropertyChange("folders");
    } catch (e) {
      console.error("Error refreshing characters", e);
    }
  }

  @computed("characters.[]")
  get mainCharacter() {
    return (this.characters || []).find((c) => c.is_main);
  }

  @computed("characters.@each.{position,folder_id}", "folders.@each.position")
  get combinedTopLevelList() {
    const unorganized = (this.characters || [])
      .filter((c) => !c.folder_id && !c.is_main)
      .map((c) => ({ ...c, type: "character" }));
    const folders = (this.folders || []).map((f) => ({ ...f, type: "folder" }));
    return [...unorganized, ...folders].sort((a, b) => a.position - b.position);
  }

  @computed("characters.@each.{position,folder_id}", "folders.[]")
  get organizedCharacters() {
    const map = {};
    (this.folders || []).forEach((f) => {
      map[f.id] = [];
    });
    const characters = [...(this.characters || [])].sort(
      (a, b) => a.position - b.position
    );
    characters.forEach((c) => {
      if (c.folder_id && map[c.folder_id]) {
        map[c.folder_id].push(c);
      }
    });
    return map;
  }

  @computed("organizedCharacters")
  get organizedCharacterCounts() {
    const counts = {};
    const organized = this.organizedCharacters;
    Object.keys(organized).forEach((folderId) => {
      counts[folderId] = organized[folderId].length;
    });
    return counts;
  }

  @action
  async onTopLevelReorder(event) {
    const { to } = event;
    const items = Array.from(
      to.querySelectorAll(":scope > .reorderable-item")
    ).map((i) => ({
      id: i.dataset.id,
      type: i.dataset.type,
    }));

    // Optimistically update local positions
    const characters = [...(this.characters || [])];
    const folders = [...(this.folders || [])];

    items.forEach((item, index) => {
      if (item.type === "character") {
        const char = characters.find((c) => c.id == item.id);
        if (char) {
          set(char, "position", index);
          set(char, "folder_id", null);
        }
      } else {
        const folder = folders.find((f) => f.id == item.id);
        if (folder) {
          set(folder, "position", index);
        }
      }
    });

    // Use a small delay before updating state to let Sortable finish its DOM work
    // This helps prevent duplicate items from appearing
    setTimeout(() => {
      this.set("characters", characters);
      this.set("folders", folders);
    }, 0);

    try {
      await ajax("/size/characters/reorder_top_level", {
        type: "POST",
        data: {
          user_id: this.user.id,
          mapping: items,
        },
      });
    } catch (e) {
      this.refreshCharacters();
    }
  }

  @action
  async onCharacterReorder(event) {
    const { to, item } = event;
    const characterId = item.dataset.id;
    const folderId = to.dataset.folderId
      ? parseInt(to.dataset.folderId, 10)
      : null;

    if (to.dataset.topLevel === "true") {
      return this.onTopLevelReorder(event);
    }

    // Update local state to avoid re-render revert
    const characters = [...(this.characters || [])];

    const items = Array.from(
      to.querySelectorAll(":scope > .reorderable-item")
    ).map((i) => i.dataset.id);

    const mapping = {};
    items.forEach((id, index) => {
      mapping[id] = index;
      const char = characters.find((c) => c.id == id);
      if (char) {
        set(char, "position", index);
        set(char, "folder_id", folderId);
      }
    });

    // Use a small delay before updating state to let Sortable finish its DOM work
    setTimeout(() => {
      this.set("characters", characters);
    }, 0);

    try {
      await ajax("/size/characters/reorder", {
        type: "POST",
        data: {
          user_id: this.user.id,
          character_mapping: mapping,
          character_ids: [characterId],
          folder_id: folderId,
        },
      });
    } catch (e) {
      this.refreshCharacters();
    }
  }

  @action
  async onFolderReorder(event) {
    const { to } = event;
    const items = Array.from(
      to.querySelectorAll(":scope > .reorderable-item")
    ).map((i) => i.dataset.id);

    const folders = [...(this.folders || [])];
    const mapping = {};
    items.forEach((id, index) => {
      mapping[id] = index;
      const folder = folders.find((f) => f.id == id);
      if (folder) {
        folder.position = index;
      }
    });

    setTimeout(() => {
      this.set("folders", folders);
    }, 0);

    try {
      await ajax("/size/folders/reorder", {
        type: "POST",
        data: {
          user_id: this.user.id,
          mapping,
        },
      });
    } catch (e) {
      this.refreshCharacters();
    }
  }
}
