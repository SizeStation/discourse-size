import { withPluginApi } from "discourse/lib/plugin-api";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import { formatSize } from "../lib/size-formatter";

export default {
  name: "discourse-size-notifications",
  initialize() {
    withPluginApi((api) => {
      if (api.registerNotificationTypeRenderer) {
        api.registerNotificationTypeRenderer(
          "discourse_size_notification",
          (NotificationTypeBase) => {
            return class extends NotificationTypeBase {
              get notificationData() {
                let data = this.notification.data;
                if (typeof data === "string") {
                  try {
                    data = JSON.parse(data);
                  } catch (e) {
                    return {};
                  }
                }
                return data || {};
              }

              get shouldRender() {
                const data = this.notificationData;
                return (
                  data &&
                  (data.character_name ||
                    data.returned ||
                    data.gift_received ||
                    data.invite)
                );
              }

              get linkTitle() {
                const data = this.notificationData;
                if (data.gift_received) {
                  return i18n(
                    "js.discourse_size.notifications.gift_received_title"
                  );
                }
                if (data.invite) {
                  return i18n(
                    "js.discourse_size.notifications.roleplay_invite_title"
                  );
                }
                return i18n("js.discourse_size.notifications.title");
              }

              get linkHref() {
                const data = this.notificationData;
                if (data.invite && data.roleplay_id) {
                  return `/size/roleplays/${data.roleplay_id}`;
                }
                return userPath(`${this.currentUser.username}/characters`);
              }

              get icon() {
                const data = this.notificationData;
                if (data.invite) {
                  return "envelope";
                }
                if (data.returned) {
                  return "undo";
                }
                if (data.gift_received) {
                  return "gift";
                }
                if (data.action_type === "grow") {
                  return "angle-double-up";
                }
                if (data.action_type === "shrink") {
                  return "angle-double-down";
                }
                return "sync";
              }

              get label() {
                const data = this.notificationData;
                if (data.invite) {
                  return i18n(
                    "js.discourse_size.notifications.roleplay_invite_label"
                  );
                }
                if (data.returned) {
                  return i18n(
                    "js.discourse_size.notifications.item_returned_label"
                  );
                }
                if (data.gift_received) {
                  return i18n(
                    "js.discourse_size.notifications.gift_received_label"
                  );
                }
                return i18n("js.discourse_size.notifications.item_used_label");
              }

              get description() {
                const data = this.notificationData;
                if (!this.shouldRender) {
                  return "";
                }

                if (data.invite) {
                  return i18n(
                    "js.discourse_size.notifications.roleplay_invite",
                    {
                      character_name: data.character_name,
                      roleplay_name: data.roleplay_name,
                    }
                  );
                }

                if (data.returned) {
                  return i18n("js.discourse_size.notifications.item_returned", {
                    item_name: data.item_name,
                    character_name: data.character_name,
                  });
                }

                if (data.gift_received) {
                  return i18n("js.discourse_size.notifications.gift_received", {
                    username: data.actor_username || "Someone",
                    item_name: data.item_name,
                  });
                }

                const actionType = data.action_type || "grow";
                const amount = data.amount_cm || 0;
                const formattedAmount = formatSize(
                  amount,
                  data.measurement_system
                );

                return i18n(`js.discourse_size.notifications.${actionType}`, {
                  username: data.actor_username || "Someone",
                  character_name: data.character_name || "your character",
                  amount: formattedAmount,
                });
              }
            };
          }
        );
      }
    });
  },
};
