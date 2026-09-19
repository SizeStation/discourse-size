import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import DiscourseSizeUseItem from "discourse/plugins/discourse-size/discourse/components/modal/discourse-size-use-item";

module("Integration | Component | DiscourseSizeUseItem", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.confirm = sinon.stub(window, "confirm").returns(true);
    this.onAction = sinon.spy();
    this.character = {
      id: 1,
      user_id: this.currentUser.id,
      name: "Small character",
    };
    this.requests = [];
    this.noSizeEffects = [
      { character_name: this.character.name, reason: "minimum_size" },
    ];
    pretender.get("/size/inventory", () =>
      response({
        inventory: [
          {
            id: 12,
            uses_remaining: 1,
            details: {
              key: "shrink_potion",
              name: "Shrink potion",
              effect: "shrink",
              amount: 25,
            },
          },
        ],
      })
    );
    pretender.post("/size/inventory/use", (request) => {
      const data = new URLSearchParams(request.requestBody);
      this.requests.push(Object.fromEntries(data));
      if (this.noSizeEffects.length && !data.has("confirm_no_size_change")) {
        return response({
          confirmation_required: true,
          no_size_effects: this.noSizeEffects,
        });
      }
      return response({ success: true });
    });
  });

  hooks.afterEach(function () {
    this.confirm.restore();
  });

  test("cancelling the no-change warning sends no consuming request and allows retry", async function (assert) {
    this.confirm.onSecondCall().returns(false);

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(DiscourseSizeUseItem, {
      model: { character: this.character, onAction: this.onAction },
    });
    await settled();
    await click(".size-inventory-card");

    assert.strictEqual(
      this.requests.length,
      1,
      "only the unconfirmed request is sent"
    );
    assert.notOk(
      this.requests[0].confirm_no_size_change,
      "consumption is not acknowledged"
    );
    assert.strictEqual(
      this.confirm.secondCall.args[0],
      [
        i18n("discourse_size.inventory.minimum_size_warning", {
          character_name: this.character.name,
        }),
        i18n("discourse_size.inventory.no_size_change_confirm"),
      ].join("\n\n"),
      "the warning explains the minimum and the cost of proceeding"
    );
    assert.false(this.onAction.called, "no successful action is reported");
    assert.dom(".discourse-size-use-item-modal").exists("the modal stays open");
    assert
      .dom(".size-inventory-card")
      .isNotDisabled("the item can be selected again");

    await click(".size-inventory-card");

    assert.strictEqual(
      this.requests.length,
      3,
      "retry checks again before confirming"
    );
    assert.strictEqual(
      this.requests[2].confirm_no_size_change,
      "true",
      "retry can proceed"
    );
    assert.true(this.onAction.calledOnce, "only the confirmed use succeeds");
  });

  test("confirming a precision warning acknowledges consumption and closes the modal", async function (assert) {
    this.noSizeEffects = [
      { character_name: this.character.name, reason: "unchanged_size" },
      { character_name: "Main character", reason: "minimum_size" },
    ];

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(DiscourseSizeUseItem, {
      model: { character: this.character, onAction: this.onAction },
    });
    await settled();
    await click(".size-inventory-card");

    assert.deepEqual(
      this.requests,
      [
        { inventory_item_id: "12", character_id: "1" },
        {
          inventory_item_id: "12",
          character_id: "1",
          confirm_no_size_change: "true",
        },
      ],
      "only the second request acknowledges no size change"
    );
    assert.strictEqual(
      this.confirm.secondCall.args[0],
      [
        i18n("discourse_size.inventory.unchanged_size_warning", {
          character_name: this.character.name,
        }),
        i18n("discourse_size.inventory.minimum_size_warning", {
          character_name: "Main character",
        }),
        i18n("discourse_size.inventory.no_size_change_confirm"),
      ].join("\n\n"),
      "both affected characters are identified"
    );
    assert.true(this.onAction.calledOnce, "the completed use is reported");
    assert
      .dom(".discourse-size-use-item-modal")
      .doesNotExist("the modal closes after success");
  });

  test("maximum-size warnings identify the limit before consuming an item", async function (assert) {
    this.noSizeEffects = [
      { character_name: this.character.name, reason: "maximum_size" },
    ];
    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(DiscourseSizeUseItem, {
      model: { character: this.character, onAction: this.onAction },
    });
    await settled();
    await click(".size-inventory-card");
    assert.strictEqual(
      this.confirm.secondCall.args[0],
      [
        i18n("discourse_size.inventory.maximum_size_warning", {
          character_name: this.character.name,
        }),
        i18n("discourse_size.inventory.no_size_change_confirm"),
      ].join("\n\n"),
      "the maximum has its own explicit warning"
    );
    assert.strictEqual(
      this.requests[1].confirm_no_size_change,
      "true",
      "consumption requires acknowledgement"
    );
  });

  for (const [blockedKey, amount] of [
    ["__all_growing__", 2e-20],
    ["__all_shrinking__", 5e-21],
  ]) {
    test(`static items respect ${blockedKey} at tiny absolute queue targets`, async function (assert) {
      this.currentUser.set("admin", false);
      Object.assign(this.character, {
        user_id: this.currentUser.id + 1,
        base_size: 170,
        current_size: 100,
        target_size: 1e-20,
        target_offset: -170,
        blocked_item_keys: [blockedKey],
      });
      pretender.get("/size/inventory", () =>
        response({
          inventory: [
            {
              id: 12,
              uses_remaining: 1,
              details: {
                key: "static_potion",
                name: "Static potion",
                effect: "static",
                amount,
              },
            },
          ],
        })
      );
      await render(<template><ModalContainer /></template>);
      this.owner.lookup("service:modal").show(DiscourseSizeUseItem, {
        model: { character: this.character },
      });
      await settled();
      assert
        .dom(".size-inventory-card")
        .doesNotExist(
          "a static item moving in the blocked direction is excluded"
        );
      assert
        .dom(".discourse-size-use-item-modal")
        .includesText("Static potion", "the blocked item is explained");
    });
  }

  test("an effective use needs no additional confirmation", async function (assert) {
    this.noSizeEffects = [];

    await render(<template><ModalContainer /></template>);
    this.owner.lookup("service:modal").show(DiscourseSizeUseItem, {
      model: { character: this.character, onAction: this.onAction },
    });
    await settled();
    await click(".size-inventory-card");

    assert.true(
      this.confirm.calledOnce,
      "only the ordinary use confirmation is shown"
    );
    assert.strictEqual(
      this.requests.length,
      1,
      "one request completes the use"
    );
    assert.true(this.onAction.calledOnce, "the completed use is reported");
  });
});
