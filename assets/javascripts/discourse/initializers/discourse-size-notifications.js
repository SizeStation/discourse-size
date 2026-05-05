import { withPluginApi } from "discourse/lib/plugin-api";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
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

              get linkTitle() {
                return i18n("discourse_size.notifications.title");
              }

              get linkHref() {
                return userPath(`${this.currentUser.username}/characters`);
              }

              get icon() {
                return this.notificationData.action_type === "grow"
                  ? "angle-double-up"
                  : "angle-double-down";
              }

              get label() {
                return this.notificationData.actor_username || "Someone";
              }

              get description() {
                const data = this.notificationData;
                const actionType = data.action_type || "grow";
                const amount = data.amount_cm || 0;
                const formattedAmount = formatSize(
                  amount,
                  data.measurement_system
                );

                return i18n(`discourse_size.notifications.${actionType}`, {
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
