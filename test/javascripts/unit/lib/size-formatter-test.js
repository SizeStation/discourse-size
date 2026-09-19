import { module, test } from "qunit";
import {
  formatSize,
  getBestUnit,
  getComparison,
  getGrowthComparison,
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

  test("growth direction follows the active absolute endpoint rather than collapsed offsets or later queued effects", function (assert) {
    const now = Date.now();
    const character = {
      base_size: 170,
      current_offset: -170,
      target_offset: -170,
      actions: [
        {
          id: 1,
          action_type: "grow",
          start_time: new Date(now - 1000).toISOString(),
          end_time: new Date(now + 1000).toISOString(),
          start_size: 1e-20,
          end_size: 2e-20,
        },
        {
          id: 2,
          action_type: "shrink",
          start_time: new Date(now + 1000).toISOString(),
          end_time: new Date(now + 2000).toISOString(),
          start_size: 2e-20,
          end_size: 1e-21,
        },
      ],
    };
    assert.true(
      getGrowthComparison(character, 1.5e-20).includes("growing"),
      "the active growth wins over the later shrink"
    );
    character.actions[0].end_size = 1e-21;
    assert.true(
      getGrowthComparison(character, 1.5e-20).includes("shrinking"),
      "tiny shrinking is visible despite identical legacy offsets"
    );
  });

  test("property-only animation is not described as height movement", function (assert) {
    const character = {
      base_size: 170,
      actions: [
        {
          action_type: "property_change",
          start_time: new Date(Date.now() - 1000).toISOString(),
          end_time: new Date(Date.now() + 1000).toISOString(),
          start_offset: 10,
          end_offset: 20,
        },
      ],
    };
    assert.strictEqual(
      getGrowthComparison(character, 170),
      null,
      "custom property changes do not imply height movement"
    );
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

  test("formatSize formats infinite sizes as ∞ and -∞", function (assert) {
    assert.strictEqual(formatSize(Infinity), "∞");
    assert.strictEqual(formatSize("Infinity"), "∞");
    assert.strictEqual(formatSize("∞"), "∞");
    assert.strictEqual(formatSize(Infinity, "imperial"), "∞");
    assert.strictEqual(formatSize("Infinity", "imperial"), "∞");
    assert.strictEqual(formatSize("∞", "imperial"), "∞");

    assert.strictEqual(formatSize(-Infinity), "-∞");
    assert.strictEqual(formatSize("-Infinity"), "-∞");
    assert.strictEqual(formatSize("-∞"), "-∞");
    assert.strictEqual(formatSize("-inf"), "-∞");
    assert.strictEqual(formatSize(-Infinity, "imperial"), "-∞");
    assert.strictEqual(formatSize("-Infinity", "imperial"), "-∞");
    assert.strictEqual(formatSize("-∞", "imperial"), "-∞");
  });

  test("getComparison handles infinite sizes", function (assert) {
    const character = { name: "Titan", current_size: Infinity };
    assert.strictEqual(getComparison(character), "Titan is infinitely large.");
    const charString = { name: "Titan", current_size: "Infinity" };
    assert.strictEqual(getComparison(charString), "Titan is infinitely large.");
    const charSymbol = { name: "Titan", current_size: "∞" };
    assert.strictEqual(getComparison(charSymbol), "Titan is infinitely large.");

    const negCharacter = { name: "Ant", current_size: -Infinity };
    assert.strictEqual(getComparison(negCharacter), "Ant is infinitely small.");
    const negCharString = { name: "Ant", current_size: "-Infinity" };
    assert.strictEqual(getComparison(negCharString), "Ant is infinitely small.");
    const negCharSymbol = { name: "Ant", current_size: "-∞" };
    assert.strictEqual(getComparison(negCharSymbol), "Ant is infinitely small.");
  });
});
