import { module, test } from "qunit";
import {
  formatSize,
  getBestUnit,
} from "discourse/plugins/discourse-size/discourse/lib/size-formatter";

module("Unit | discourse-size | size-formatter", function () {
  test("formatSize formats subatomic tiers correctly in metric", function (assert) {
    assert.strictEqual(formatSize(1e-37, "metric"), "< 0.001 ℓP");
    assert.strictEqual(formatSize(1e-35, "metric"), "0,006 ℓP");
    assert.strictEqual(formatSize(1.616255e-33, "metric"), "1,00 ℓP");
    assert.strictEqual(formatSize(1e-28, "metric"), "1,00 qm");
    assert.strictEqual(formatSize(1e-25, "metric"), "1,00 rm");
    assert.strictEqual(formatSize(1e-22, "metric"), "1,00 ym");
    assert.strictEqual(formatSize(1e-19, "metric"), "1,00 zm");
    assert.strictEqual(formatSize(1e-16, "metric"), "1,00 am");
    assert.strictEqual(formatSize(1e-13, "metric"), "1,00 fm");
    assert.strictEqual(formatSize(1e-10, "metric"), "1,00 pm");
  });

  test("formatSize formats subatomic tiers correctly in imperial", function (assert) {
    assert.strictEqual(formatSize(1e-37, "imperial"), "< 0.001 ℓP");
    assert.strictEqual(formatSize(1e-35, "imperial"), "0.006 ℓP");
    assert.strictEqual(formatSize(1.616255e-33, "imperial"), "1.00 ℓP");
    assert.strictEqual(formatSize(1e-28, "imperial"), "1.00 qm");
    assert.strictEqual(formatSize(1e-25, "imperial"), "1.00 rm");
    assert.strictEqual(formatSize(1e-22, "imperial"), "1.00 ym");
    assert.strictEqual(formatSize(1e-19, "imperial"), "1.00 zm");
    assert.strictEqual(formatSize(1e-16, "imperial"), "1.00 am");
    assert.strictEqual(formatSize(1e-13, "imperial"), "1.00 fm");
    assert.strictEqual(formatSize(1e-10, "imperial"), "1.00 pm");
  });

  test("getBestUnit selects appropriate subatomic unit", function (assert) {
    assert.strictEqual(getBestUnit(1e-35).id, "planck");
    assert.strictEqual(getBestUnit(1e-28).id, "qm");
    assert.strictEqual(getBestUnit(1e-25).id, "rm");
    assert.strictEqual(getBestUnit(1e-22).id, "ym");
    assert.strictEqual(getBestUnit(1e-19).id, "zm");
    assert.strictEqual(getBestUnit(1e-16).id, "am");
    assert.strictEqual(getBestUnit(1e-13).id, "fm");
    assert.strictEqual(getBestUnit(1e-10).id, "pm");
  });
});
