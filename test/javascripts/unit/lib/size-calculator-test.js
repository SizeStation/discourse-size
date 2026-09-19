import { module, test } from "qunit";
import {
  calculateOffset,
  calculatePropertyValue,
  calculateSize,
  calculateTargetSize,
  getActionEndSize,
  getActionStartSize,
  isInfiniteSize,
  MAX_SIZE,
  MIN_SIZE,
} from "discourse/plugins/discourse-size/discourse/lib/size-calculator";

function heightAction(startSize, endSize, overrides = {}) {
  return {
    id: 1,
    action_type: endSize < startSize ? "shrink" : "grow",
    start_time: new Date(1000).toISOString(),
    end_time: new Date(2000).toISOString(),
    start_size: startSize,
    end_size: endSize,
    start_offset: -170,
    end_offset: -170,
    ...overrides,
  };
}

module("Unit | Lib | size-calculator", function () {
  test("tiny shrink and grow interpolate absolute endpoints despite identical offsets", function (assert) {
    for (const [start, end] of [
      [1e-20, 1e-21],
      [1e-21, 1e-20],
    ]) {
      const character = { base_size: 170, actions: [heightAction(start, end)] };
      assert.strictEqual(
        calculateSize(character, new Date(1000)),
        start,
        "the exact start is preserved"
      );
      assert.strictEqual(
        calculateSize(character, new Date(1500)),
        0.5 * start + 0.5 * end,
        "the midpoint uses absolute heights"
      );
      assert.strictEqual(
        calculateSize(character, new Date(2000)),
        end,
        "the exact destination is preserved"
      );
      assert.strictEqual(
        calculateTargetSize(character),
        end,
        "the queue target is absolute"
      );
    }
  });

  test("huge-to-tiny shrink reaches its exact final endpoint", function (assert) {
    const character = {
      base_size: MAX_SIZE,
      actions: [heightAction(MAX_SIZE, 1e-30)],
    };
    assert.strictEqual(
      calculateSize(character, new Date(1000)),
      MAX_SIZE,
      "the start boundary is exact"
    );
    assert.strictEqual(
      calculateSize(character, new Date(1999)),
      (1 - 0.999) * MAX_SIZE + 0.999 * 1e-30,
      "the last interpolated value uses weighted endpoints"
    );
    assert.strictEqual(
      calculateSize(character, new Date(2000)),
      1e-30,
      "the end boundary does not cancel to zero"
    );
    assert.strictEqual(
      calculateSize(character, new Date(3000)),
      1e-30,
      "the final size remains exact after completion"
    );
  });

  test("growth from minimum and shrink from maximum preserve bounds", function (assert) {
    for (const [start, end] of [
      [MIN_SIZE, 2 * MIN_SIZE],
      [MAX_SIZE, MAX_SIZE / 2],
    ]) {
      const character = { base_size: 170, actions: [heightAction(start, end)] };
      assert.strictEqual(
        calculateSize(character, new Date(1500)),
        0.5 * start + 0.5 * end,
        "movement away from a limit remains possible"
      );
      assert.strictEqual(
        calculateSize(character, new Date(2000)),
        end,
        "the destination is exact"
      );
    }
    const character = { base_size: 170, actions: [heightAction(0, 1e130)] };
    assert.strictEqual(
      calculateSize(character, new Date(1000)),
      MIN_SIZE,
      "undersized endpoints clamp to minimum"
    );
    assert.strictEqual(
      calculateSize(character, new Date(2000)),
      MAX_SIZE,
      "oversized endpoints clamp to maximum"
    );
  });

  test("nonfinite absolute and legacy heights sanitize to minimum", function (assert) {
    for (const invalid of [NaN, Infinity, -Infinity, "invalid"]) {
      const character = { base_size: 170, actions: [] };
      const action = heightAction(invalid, invalid);
      assert.strictEqual(
        getActionStartSize(character, action),
        MIN_SIZE,
        "invalid absolute starts sanitize"
      );
      assert.strictEqual(
        getActionEndSize(character, action),
        MIN_SIZE,
        "invalid absolute ends sanitize"
      );
      assert.strictEqual(
        getActionEndSize(character, { end_offset: invalid }),
        MIN_SIZE,
        "invalid legacy endpoints sanitize"
      );
      assert.strictEqual(
        calculateSize({ base_size: invalid, actions: [] }),
        MIN_SIZE,
        "invalid bases sanitize"
      );
    }
  });

  test("legacy actions use base plus offset when absolute fields are absent", function (assert) {
    const action = heightAction(null, undefined, {
      start_offset: 10,
      end_offset: 30,
    });
    const character = { base_size: "170", actions: [action] };
    assert.strictEqual(
      getActionStartSize(character, action),
      180,
      "a null start falls back to the legacy offset"
    );
    assert.strictEqual(
      getActionEndSize(character, action),
      200,
      "a missing end falls back to the legacy offset"
    );
    assert.strictEqual(
      calculateSize(character, new Date(1500)),
      190,
      "legacy interpolation remains supported"
    );
    assert.strictEqual(
      calculateOffset(character, new Date(1500)),
      20,
      "the compatibility offset derives from absolute size"
    );
    assert.strictEqual(
      getActionEndSize(character, { end_offset: -200 }),
      MIN_SIZE,
      "legacy underflow clamps"
    );
    assert.strictEqual(
      getActionEndSize(character, { end_offset: 1e130 }),
      MAX_SIZE,
      "legacy overflow clamps"
    );
  });

  test("chronological endpoints cover future actions, gaps, and simultaneous instant changes", function (assert) {
    const first = heightAction(1e-20, 2e-20);
    const second = heightAction(2e-20, 3e-20, {
      id: 2,
      start_time: new Date(4000).toISOString(),
      end_time: new Date(4000).toISOString(),
      created_at: new Date(6000).toISOString(),
    });
    const third = {
      ...second,
      id: 3,
      start_size: 3e-20,
      end_size: 4e-20,
      created_at: new Date(5000).toISOString(),
    };
    const character = {
      base_size: 170,
      target_size: 999,
      actions: [third, second, first],
    };
    assert.strictEqual(
      calculateSize(character, new Date(0)),
      1e-20,
      "before the queue uses its first start"
    );
    assert.strictEqual(
      calculateSize(character, new Date(3000)),
      2e-20,
      "gaps retain the most recent endpoint"
    );
    assert.strictEqual(
      calculateSize(character, new Date(4000)),
      4e-20,
      "simultaneous actions break ties by id, not creation time"
    );
    assert.strictEqual(
      calculateTargetSize(character),
      3e-20,
      "the append target uses creation order, matching the server even when animation order differs"
    );
  });

  test("empty or non-height history uses base rather than stale serialized state", function (assert) {
    const character = {
      base_size: 170,
      current_size: 1e-20,
      target_size: 2e-20,
      current_offset: -170,
      target_offset: -170,
      actions: [],
    };
    assert.strictEqual(
      calculateSize(character),
      170,
      "an empty history matches Ruby's base size"
    );
    assert.strictEqual(
      calculateTargetSize(character),
      170,
      "an empty queue targets the base"
    );
    character.actions = [
      heightAction(1, 2, { action_type: "property_change" }),
      heightAction(1, 2, { start_time: null }),
    ];
    assert.strictEqual(
      calculateSize(character),
      170,
      "properties and undated actions are not height history"
    );
    assert.strictEqual(
      calculateTargetSize(character),
      2,
      "undated height actions still participate in the append chain, matching the server"
    );
  });

  test("summary payloads use serialized current and target heights independently", function (assert) {
    const character = {
      base_size: 170,
      current_size: 1e-20,
      target_size: 2e-20,
      current_offset: -170,
      target_offset: -170,
    };
    assert.strictEqual(
      calculateSize(character),
      1e-20,
      "omitted history uses serialized current size"
    );
    assert.strictEqual(
      calculateTargetSize(character),
      2e-20,
      "omitted history uses serialized queue target"
    );
    assert.strictEqual(
      calculateSize({ base_size: 170, current_offset: 0, target_offset: 30 }),
      170,
      "legacy zero current offset is not replaced by target offset"
    );
    assert.strictEqual(
      calculateTargetSize({
        base_size: 170,
        current_offset: 10,
        target_offset: 30,
      }),
      200,
      "legacy summary targets retain compatibility"
    );
  });

  test("custom properties continue to interpolate offsets without height clamping", function (assert) {
    const character = {
      base_size: 170,
      actions: [
        heightAction(100, 200, {
          action_type: "property_change",
          item_key: "Tail",
          start_offset: -10,
          end_offset: 0,
        }),
      ],
    };
    assert.strictEqual(
      calculatePropertyValue(character, "Tail", new Date(1500)),
      -5,
      "property offsets remain authoritative"
    );
    assert.strictEqual(
      calculatePropertyValue(character, "Tail", new Date(2000)),
      0,
      "zero property endpoints are not height-clamped"
    );
  });

  test("isInfiniteSize identifies infinite values correctly", function (assert) {
    assert.true(isInfiniteSize(Infinity));
    assert.true(isInfiniteSize(-Infinity));
    assert.true(isInfiniteSize("Infinity"));
    assert.true(isInfiniteSize("+infinity"));
    assert.true(isInfiniteSize("-infinity"));
    assert.true(isInfiniteSize("infinite"));
    assert.true(isInfiniteSize("-infinite"));
    assert.true(isInfiniteSize("∞"));
    assert.true(isInfiniteSize("-∞"));
    assert.true(isInfiniteSize("inf"));
    assert.true(isInfiniteSize("+inf"));
    assert.true(isInfiniteSize("-inf"));
    assert.true(isInfiniteSize("inf cm"));
    assert.true(isInfiniteSize("-inf cm"));
    assert.true(isInfiniteSize("infinity cm"));
    assert.true(isInfiniteSize("-infinity cm"));

    assert.false(isInfiniteSize(100));
    assert.false(isInfiniteSize("100"));
    assert.false(isInfiniteSize(0));
    assert.false(isInfiniteSize(null));
    assert.false(isInfiniteSize(undefined));
    assert.false(isInfiniteSize(NaN));
  });

  test("normal characters support unclamped sizes and infinity", function (assert) {
    const tinyNormal = {
      character_type: "normal",
      base_size: 1e-40,
    };
    assert.strictEqual(
      calculateSize(tinyNormal),
      1e-40,
      "normal character can be below MIN_SIZE"
    );
    assert.strictEqual(
      calculateTargetSize(tinyNormal),
      1e-40,
      "normal character target size can be below MIN_SIZE"
    );

    const hugeNormal = {
      character_type: "normal",
      base_size: 1e150,
    };
    assert.strictEqual(
      calculateSize(hugeNormal),
      1e150,
      "normal character can be above MAX_SIZE"
    );
    assert.strictEqual(
      calculateTargetSize(hugeNormal),
      1e150,
      "normal character target size can be above MAX_SIZE"
    );

    const infiniteNormal = {
      character_type: "normal",
      base_size: Infinity,
    };
    assert.strictEqual(
      calculateSize(infiniteNormal),
      Infinity,
      "normal character can have infinite size"
    );
    assert.strictEqual(
      calculateTargetSize(infiniteNormal),
      Infinity,
      "normal character target size can be infinity"
    );
    assert.strictEqual(
      calculateOffset(infiniteNormal),
      0,
      "infinite offset returns 0 without NaN"
    );

    const infiniteStringNormal = {
      character_type: "normal",
      base_size: "∞",
    };
    assert.strictEqual(
      calculateSize(infiniteStringNormal),
      Infinity,
      "normal character base_size '∞' calculates to Infinity"
    );

    const negInfiniteNormal = {
      character_type: "normal",
      base_size: -Infinity,
    };
    assert.strictEqual(
      calculateSize(negInfiniteNormal),
      -Infinity,
      "normal character can have negative infinite size"
    );
    assert.strictEqual(
      calculateTargetSize(negInfiniteNormal),
      -Infinity,
      "normal character target size can be -Infinity"
    );

    const negInfiniteStringNormal = {
      character_type: "normal",
      base_size: "-∞",
    };
    assert.strictEqual(
      calculateSize(negInfiniteStringNormal),
      -Infinity,
      "normal character base_size '-∞' calculates to -Infinity"
    );

    const negInfWordNormal = {
      character_type: "normal",
      base_size: "-inf",
    };
    assert.strictEqual(
      calculateSize(negInfWordNormal),
      -Infinity,
      "normal character base_size '-inf' calculates to -Infinity"
    );
  });
});
