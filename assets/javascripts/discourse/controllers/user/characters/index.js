import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

import DiscourseSizeEditCharacter from "../../../components/modal/discourse-size-edit-character";
import DiscourseSizeEditFolder from "../../../components/modal/discourse-size-edit-folder";
import DiscourseSizeAdminPoints from "../../../components/modal/discourse-size-admin-points";

export default class UserCharactersIndexController extends Controller {
  @service currentUser;
  @service modal;
  @service siteSettings;

  get isCurrentUser() {
    return this.currentUser && this.currentUser.id === this.user?.id;
  }

  @action
  adminEditPoints() {
    this.modal.show(DiscourseSizeAdminPoints, {
      model: {
        user: this.user,
        points: this.user.discourse_size_points,
        onSave: (newPoints) => {
          this.set("user.discourse_size_points", parseInt(newPoints, 10));
        },
      },
    });
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

    // If it's a simple character update, try to update in-place to avoid full reload
    if (result && result.character) {
      const characters = this.get("characters") || [];
      const index = characters.findIndex((c) => c.id === result.character.id);
      if (index !== -1) {
        const newCharacters = [...characters];
        newCharacters[index] = result.character;
        this.set("characters", newCharacters);
        return;
      }
    }

    try {
      const res = await ajax(`/size/characters?user_id=${this.user.id}`);
      this.set("characters", res.characters || []);
      this.set("folders", res.folders || []);
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
          char.position = index;
          char.folder_id = null;
        }
      } else {
        const folder = folders.find((f) => f.id == item.id);
        if (folder) {
          folder.position = index;
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
        char.position = index;
        char.folder_id = folderId;
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
