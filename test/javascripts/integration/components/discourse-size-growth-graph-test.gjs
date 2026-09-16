import {
  fillIn,
  findAll,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DiscourseSizeGrowthGraph from "discourse/plugins/discourse-size/discourse/components/modal/discourse-size-growth-graph";
import { formatSize } from "discourse/plugins/discourse-size/discourse/lib/size-formatter";

module("Integration | Component | DiscourseSizeGrowthGraph", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("an end date alone excludes later effects and clips ongoing size and property changes", async function (assert) {
    const changes = [
      {
        start_time: "2026-01-01T00:00:00",
        end_time: "2026-01-01T12:00:00",
        from: 1,
        to: 2,
      },
      {
        start_time: "2026-01-02T12:00:00",
        end_time: "2026-01-03T12:00:00",
        from: 2,
        to: 4,
      },
      {
        start_time: "2026-01-04T00:00:00",
        end_time: "2026-01-04T12:00:00",
        from: 4,
        to: 8,
      },
    ];
    const character = {
      id: 1,
      name: "Test character",
      base_size: 100,
      measurement_system: "metric",
      actions: changes.flatMap((change, index) => [
        {
          id: index * 2 + 1,
          action_type: "grow",
          user: this.currentUser,
          created_at: change.start_time,
          start_time: change.start_time,
          end_time: change.end_time,
          start_offset: change.from * 100 - 100,
          end_offset: change.to * 100 - 100,
        },
        {
          id: index * 2 + 2,
          action_type: "property_change",
          item_key: "Tail",
          user: this.currentUser,
          created_at: change.start_time,
          start_time: change.start_time,
          end_time: change.end_time,
          start_offset: change.from * 10,
          end_offset: change.to * 10,
        },
      ]),
    };
    this.currentUser.set("discourse_size_settings", {
      measurement_system: "metric",
    });

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(DiscourseSizeGrowthGraph, {
      model: { character },
    });
    await settled();
    await fillIn("#growth-graph-start-date", "");
    await fillIn("#growth-graph-end-date", "2026-01-02");

    assert
      .dom(".growth-svg .graph-point")
      .exists(
        { count: 8 },
        "both series exclude later actions and current-time points"
      );

    const expectedValues = [100, 200, 200, 300, 10, 20, 20, 30];
    const points = findAll(".growth-svg .graph-point");
    for (const [index, point] of points.entries()) {
      await triggerEvent(point, "mouseenter");
      assert
        .dom(".graph-tooltip .tooltip-size")
        .hasText(
          formatSize(expectedValues[index], "metric"),
          `point ${index + 1} shows the historical value, interpolated at the cutoff when needed`
        );
    }
  });

  test("set-size history displays each action endpoint", async function (assert) {
    const character = {
      id: 1,
      user_id: this.currentUser.id,
      name: "Test character",
      base_size: 100,
      current_size: 300,
      current_offset: 200,
      target_offset: 200,
      measurement_system: "metric",
      actions: [300, 200].map((size, index) => {
        const timestamp = new Date(
          Date.now() - (index + 1) * 60000
        ).toISOString();
        return {
          id: index + 1,
          action_type: "set_size",
          user: this.currentUser,
          size_change: 100,
          start_offset: size - 200,
          end_offset: size - 100,
          end_total_size: size,
          created_at: timestamp,
          start_time: timestamp,
          end_time: timestamp,
        };
      }),
    };

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(DiscourseSizeGrowthGraph, {
      model: { character },
    });
    await settled();

    assert
      .dom(".modal-activity-list .activity-item:nth-child(1) .activity-text")
      .includesText(
        formatSize(300, "metric"),
        "the latest entry shows its endpoint"
      );
    assert
      .dom(".modal-activity-list .activity-item:nth-child(2) .activity-text")
      .includesText(
        formatSize(200, "metric"),
        "the older entry retains its own endpoint"
      );
  });
});
