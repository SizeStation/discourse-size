# frozen_string_literal: true

require "rails_helper"

describe DiscourseSizeCharacter do
  fab!(:user)
  fab!(:folder) { DiscourseSizeFolder.create!(user: user, name: "My Folder") }
  fab!(:character_1) do
    Fabricate(:discourse_size_character, user: user, folder_id: folder.id, is_main: false)
  end
  fab!(:character_2) do
    Fabricate(:discourse_size_character, user: user, folder_id: folder.id, is_main: false)
  end

  it "preserves folder_id when setting character as main" do
    character_1.update!(is_main: true)

    expect(character_1.reload.folder_id).to eq(folder.id)
    expect(character_1.is_main).to be true
  end

  it "unsets is_main on previous main character while preserving folder_id for both" do
    character_1.update!(is_main: true)
    character_2.update!(is_main: true)

    expect(character_1.reload.is_main).to be false
    expect(character_1.folder_id).to eq(folder.id)

    expect(character_2.reload.is_main).to be true
    expect(character_2.folder_id).to eq(folder.id)
  end

  it "preserves folder_id when unsetting character as main" do
    character_1.update!(is_main: true)
    character_1.update!(is_main: false)

    expect(character_1.reload.folder_id).to eq(folder.id)
    expect(character_1.is_main).to be false
  end

  describe "#destroy_with_linked_effects!" do
    fab!(:actor, :user)
    fab!(:main_character) do
      Fabricate(
        :discourse_size_character,
        user: actor,
        is_main: true,
        character_type: DiscourseSizeCharacter::TYPE_GAME,
        base_size: 100.0,
      )
    end
    fab!(:paired_item) do
      DiscourseSizeShopItem.create!(
        key: "paired_growth",
        name: "Paired growth",
        price: 0,
        effect: "grow",
        amount: 50.0,
        self_effect: "grow",
        self_amount: 20.0,
        duration_minutes: 0,
        uses: 1,
      )
    end
    fab!(:growth_item) do
      DiscourseSizeShopItem.create!(
        key: "grow_half",
        name: "Grow half",
        price: 0,
        effect: "grow",
        amount: 50.0,
        duration_minutes: 0,
        uses: 1,
      )
    end

    before do
      freeze_time
      inventory_item =
        DiscourseSizeInventory.create!(
          user_id: actor.id,
          item_key: paired_item.key,
          uses_remaining: 1,
        )
      DiscourseSize::InventoryManager.use_item(actor, inventory_item.id, character_1.id)
    end

    it "recalculates surviving percentage effects after deleting linked self-effects" do
      main_character.reload.add_queued_action(
        action_type: "grow",
        size_change: 60.0,
        duration_minutes: 0,
        user_id: actor.id,
        item_key: growth_item.key,
      )
      expect(main_character.current_size).to eq(180.0)
      linked_action = main_character.discourse_size_actions.find_by!(item_key: paired_item.key)

      character_1.destroy_with_linked_effects!

      expect(DiscourseSizeCharacter.exists?(character_1.id)).to be false
      expect(DiscourseSizeAction.exists?(linked_action.id)).to be false
      expect(main_character.reload.current_size).to eq(150.0)
      expect(main_character.target_offset).to eq(50.0)
      remaining_action = main_character.discourse_size_actions.sole
      expect(remaining_action.start_offset).to eq(0.0)
      expect(remaining_action.end_offset).to eq(50.0)
      expect(remaining_action.size_change).to eq(50.0)
    end

    it "returns surviving characters to their base when no size effects remain" do
      character_1.destroy_with_linked_effects!

      expect(main_character.reload.current_size).to eq(100.0)
      expect(main_character.current_offset).to eq(0.0)
      expect(main_character.target_offset).to eq(0.0)
      expect(main_character.discourse_size_actions).to be_empty
    end

    it "recalculates active and queued effects on surviving characters" do
      [60.0, 90.0].each do |size_change|
        main_character.reload.add_queued_action(
          action_type: "grow",
          size_change: size_change,
          duration_minutes: 60,
          user_id: actor.id,
          item_key: growth_item.key,
        )
      end
      freeze_time 30.minutes.from_now

      character_1.destroy_with_linked_effects!

      expect(main_character.reload.current_size).to be_within(1e-6).of(125.0)
      expect(main_character.base_size + main_character.target_offset).to eq(225.0)
      expect(main_character.size_at(2.hours.from_now)).to eq(225.0)
    end

    it "rolls back deletion if a surviving character cannot be recalculated" do
      main_character.update_column(:character_type, "invalid")
      action_ids = DiscourseSizeAction.order(:id).pluck(:id)

      expect { character_1.destroy_with_linked_effects! }.to raise_error(
        ActiveRecord::RecordInvalid,
      )

      expect(DiscourseSizeCharacter.exists?(character_1.id)).to be true
      expect(DiscourseSizeAction.order(:id).pluck(:id)).to eq(action_ids)
      expect(main_character.reload.target_offset).to eq(20.0)
    end
  end

  describe "#update!" do
    fab!(:growth_item) do
      DiscourseSizeShopItem.create!(
        key: "double_size",
        name: "Double size",
        price: 0,
        effect: "grow",
        amount: 100.0,
        uses: 1,
      )
    end

    before do
      SiteSetting.discourse_size_min_base_size = 1.0
      freeze_time
    end

    it "immediately recalculates completed percentage effects against the new base size" do
      character_1.update!(character_type: DiscourseSizeCharacter::TYPE_GAME, base_size: 100.0)
      action =
        character_1.add_queued_action(
          action_type: "grow",
          size_change: 100.0,
          duration_minutes: 0,
          user_id: user.id,
          item_key: growth_item.key,
        )[
          :action
        ]
      expect(character_1.current_size).to eq(200.0)

      character_1.update!(base_size: 200.0)

      expect(character_1.reload.current_size).to eq(400.0)
      expect(character_1.current_offset).to eq(200.0)
      expect(character_1.target_offset).to eq(200.0)
      expect(action.reload.start_offset).to eq(0.0)
      expect(action.end_offset).to eq(200.0)
      expect(action.size_change).to eq(200.0)
    end

    it "recalculates active and queued effects without changing their timing" do
      character_1.update!(character_type: DiscourseSizeCharacter::TYPE_GAME, base_size: 100.0)
      actions =
        [100.0, 200.0].map do |size_change|
          character_1.add_queued_action(
            action_type: "grow",
            size_change: size_change,
            duration_minutes: 60,
            user_id: user.id,
            item_key: growth_item.key,
          )[
            :action
          ].reload
        end
      times = actions.map { |action| [action.start_time, action.end_time] }
      freeze_time 30.minutes.from_now
      expect(character_1.current_size).to be_within(1e-6).of(150.0)

      character_1.update!(base_size: 200.0)

      expect(character_1.reload.current_size).to be_within(1e-6).of(300.0)
      expect(character_1.base_size + character_1.target_offset).to eq(800.0)
      expect(actions.map { |action| action.reload.end_offset }).to eq([200.0, 600.0])
      expect(actions.map { |action| [action.start_time, action.end_time] }).to eq(times)
    end

    it "preserves absolute set-size targets when the base size changes" do
      character_1.update!(character_type: DiscourseSizeCharacter::TYPE_GAME, base_size: 100.0)
      character_1.update_size(250.0, user)

      character_1.update!(base_size: 200.0)

      expect(character_1.reload.current_size).to eq(250.0)
      expect(character_1.base_size + character_1.target_offset).to eq(250.0)
    end

    it "does not shift offsets when character has no actions and zero offsets" do
      character_1.update!(
        character_type: DiscourseSizeCharacter::TYPE_GAME,
        base_size: 170.0,
        current_offset: 0.0,
        target_offset: 0.0,
        start_offset: 0.0,
      )

      character_1.update!(base_size: 180.0)
      character_1.reload

      expect(character_1.current_offset).to eq(0.0)
      expect(character_1.target_offset).to eq(0.0)
      expect(character_1.current_size).to eq(180.0)
    end

    it "reapplies fixed growth on microscopic base size changes" do
      SiteSetting.discourse_size_min_base_size = 1e-25
      character_1.update!(
        character_type: DiscourseSizeCharacter::TYPE_GAME,
        base_size: 1.0e-18,
        current_offset: 0.0,
        target_offset: 1.0e-19,
        start_offset: 0.0,
      )

      action =
        DiscourseSizeAction.create!(
          character_id: character_1.id,
          user_id: user.id,
          action_type: "grow",
          size_change: 1.0e-19,
          start_offset: 0.0,
          end_offset: 1.0e-19,
          duration_minutes: 60,
          start_time: Time.now,
          end_time: Time.now + 60.minutes,
        )

      character_1.update!(base_size: 1.1e-18)
      character_1.reload
      action.reload

      expect(character_1.current_size).to be_within(1e-22).of(1.1e-18)
      expect(character_1.base_size + action.end_offset).to be_within(1e-22).of(1.2e-18)
    end
  end

  describe "subatomic minimum size" do
    it "allows creating normal characters at subatomic and Planck scales" do
      char =
        Fabricate(
          :discourse_size_character,
          user: user,
          character_type: DiscourseSizeCharacter::TYPE_NORMAL,
          base_size: 1e-33,
        )
      expect(char.base_size).to eq(1e-33)
      expect(char.valid?).to be true
    end

    it "rejects normal characters below MIN_SIZE" do
      char =
        Fabricate.build(
          :discourse_size_character,
          user: user,
          character_type: DiscourseSizeCharacter::TYPE_NORMAL,
          base_size: 1e-36,
        )
      expect(char.valid?).to be false
      expect(char.errors[:base_size]).to be_present
    end

    it "clamps target_offset to MIN_SIZE in update_size_target" do
      character_1.update!(
        character_type: DiscourseSizeCharacter::TYPE_NORMAL,
        base_size: 1e-33,
        current_offset: 0.0,
        target_offset: 0.0,
      )

      character_1.update_size_target(-10.0)
      character_1.reload

      expect(character_1.base_size + character_1.target_offset).to be_within(1e-45).of(
        DiscourseSizeCharacter::MIN_SIZE,
      )
    end

    it "clamps new size to MIN_SIZE in update_size" do
      character_1.update!(
        character_type: DiscourseSizeCharacter::TYPE_NORMAL,
        base_size: 1e-33,
        current_offset: 0.0,
        target_offset: 0.0,
      )

      character_1.update_size(1e-40, user)
      character_1.reload

      expect(character_1.current_size).to eq(DiscourseSizeCharacter::MIN_SIZE)
      expect(character_1.base_size + character_1.target_offset).to be_within(1e-45).of(
        DiscourseSizeCharacter::MIN_SIZE,
      )
    end

    it "clamps size_change to MIN_SIZE in add_queued_action" do
      character_1.update!(
        character_type: DiscourseSizeCharacter::TYPE_NORMAL,
        base_size: 1e-33,
        current_offset: 0.0,
        target_offset: 0.0,
      )

      res =
        character_1.add_queued_action(
          action_type: "shrink",
          size_change: -10.0,
          duration_minutes: 60,
          user_id: user.id,
        )

      expect(res[:capped]).to eq(:min)
      expect(character_1.base_size + character_1.target_offset).to be_within(1e-45).of(
        DiscourseSizeCharacter::MIN_SIZE,
      )
      expect(character_1.size_at(Time.now + 60.minutes)).to be_within(1e-45).of(
        DiscourseSizeCharacter::MIN_SIZE,
      )
    end

    it "correctly reports is_min_size? and is_max_size?" do
      expect(character_1.is_min_size?).to be false
      expect(character_1.is_max_size?).to be false

      character_1.update_columns(
        base_size: DiscourseSizeCharacter::MIN_SIZE,
        current_offset: 0,
        target_offset: 0,
      )
      expect(character_1.is_min_size?).to be true
      expect(character_1.is_max_size?).to be false

      character_1.update_columns(
        base_size: DiscourseSizeCharacter::MAX_SIZE,
        current_offset: 0,
        target_offset: 0,
      )
      expect(character_1.is_min_size?).to be false
      expect(character_1.is_max_size?).to be true
    end
  end

  describe "#current_size" do
    it "returns the minimum size when an action produces a non-finite offset" do
      character_1.update_columns(
        base_size: 100.0,
        current_offset: 0.0,
        target_offset: 0.0,
      )
      DiscourseSizeAction.create!(
        character_id: character_1.id,
        user_id: user.id,
        action_type: "set_size",
        size_change: 0.0,
        start_offset: Float::NAN,
        end_offset: Float::NAN,
        duration_minutes: 0,
        start_time: Time.current,
        end_time: Time.current,
      )

      expect(character_1.reload.current_size).to eq(DiscourseSizeCharacter::MIN_SIZE)
      character_1.sync_offset!
      expect(character_1.reload.current_offset).to eq(
        DiscourseSizeCharacter::MIN_SIZE - character_1.base_size,
      )
    end

    it "caps a calculated size above the maximum size" do
      character_1.update_columns(
        base_size: DiscourseSizeCharacter::MAX_SIZE,
        current_offset: DiscourseSizeCharacter::MAX_SIZE,
        target_offset: DiscourseSizeCharacter::MAX_SIZE,
      )

      expect(character_1.reload.current_size).to eq(DiscourseSizeCharacter::MAX_SIZE)
    end
  end
end
