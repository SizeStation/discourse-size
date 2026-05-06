import { withPluginApi } from "discourse/lib/plugin-api";
import { userPath } from "discourse/lib/url";
import I18n from "I18n";
import { formatSize } from "../lib/size-formatter";

export default {
  name: "discourse-size-notifications",
  initialize() {
    withPluginApi("1.1.0", (api) => {
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
                // Only render if it's our notification data structure
                return (
                  data &&
                  (data.character_name || data.returned || data.gift_received)
                );
              }

              get linkTitle() {
                const data = this.notificationData;
                if (data.gift_received) {
                  return I18n.t("js.discourse_size.notifications.gift_received_title");
                }
                return I18n.t("js.discourse_size.notifications.title");
              }

              get linkHref() {
                return userPath(`${this.currentUser.username}/characters`);
              }

              get icon() {
                const data = this.notificationData;
                if (data.returned) {
                  return "undo";
                }
                if (data.gift_received) {
                  return "gift";
                }
                return data.action_type === "grow"
                  ? "angle-double-up"
                  : "angle-double-down";
              }

              get label() {
                const data = this.notificationData;
                if (data.returned) {
                  return I18n.t(
                    "js.discourse_size.notifications.item_returned_label"
                  );
                }
                if (data.gift_received) {
                  return I18n.t(
                    "js.discourse_size.notifications.gift_received_label"
                  );
                }
                return I18n.t("js.discourse_size.notifications.item_used_label");
              }

              get description() {
                const data = this.notificationData;
                if (!this.shouldRender) {
                  return "";
                }

                if (data.returned) {
                  return I18n.t(
                    "js.discourse_size.notifications.item_returned",
                    {
                      item_name: data.item_name,
                      character_name: data.character_name,
                    }
                  );
                }

                if (data.gift_received) {
                  return I18n.t(
                    "js.discourse_size.notifications.gift_received",
                    {
                      username: data.actor_username || "Someone",
                      item_name: data.item_name,
                    }
                  );
                }

                const actionType = data.action_type || "grow";
                const amount = data.amount_cm || 0;
                const formattedAmount = formatSize(
                  amount,
                  data.measurement_system
                );

                return I18n.t(`js.discourse_size.notifications.${actionType}`, {
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
