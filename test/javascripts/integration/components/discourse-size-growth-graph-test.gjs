import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DiscourseSizeGrowthGraph from "discourse/plugins/discourse-size/discourse/components/modal/discourse-size-growth-graph";
import { formatSize } from "discourse/plugins/discourse-size/discourse/lib/size-formatter";

module("Integration | Component | DiscourseSizeGrowthGraph", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

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
