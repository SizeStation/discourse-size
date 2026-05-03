import { withPluginApi } from "discourse/lib/plugin-api";
import { formatSize, getComparison } from "../lib/size-formatter";

export default {
  name: "discourse-size",
  initialize() {
    withPluginApi("0.8", (api) => {
    });
  },
};
