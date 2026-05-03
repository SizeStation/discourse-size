import { registerRawHelper } from "discourse-common/lib/helpers";
import { formatSize } from "../lib/size-formatter";

// In Discourse, helpers are often registered like this or as Gjs
// But for standard plugins, we use registerRawHelper or a class-based helper.
// I'll use a standard Ember helper if possible.

import { helper } from "@ember/component/helper";

export default helper(function ([size, system]) {
  return formatSize(size, system);
});
