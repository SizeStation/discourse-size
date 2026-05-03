import { helper } from "@ember/component/helper";

export default helper(function ([value]) {
  return Math.abs(parseFloat(value) || 0);
});
