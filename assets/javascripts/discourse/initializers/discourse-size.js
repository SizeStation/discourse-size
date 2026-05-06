import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-size",
  initialize() {
    withPluginApi("0.8", (api) => {
    });
  },
};
