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

  describe "adjust_offsets_on_base_size_change" do
    before { SiteSetting.discourse_size_min_base_size = 1.0 }

    it "shifts offsets and actions when base_size changes on a game character with actions" do
      character_1.update!(
        character_type: DiscourseSizeCharacter::TYPE_GAME,
        base_size: 170.0,
        current_offset: -169.9999,
        target_offset: -169.9999,
        start_offset: -169.9999,
      )

      action =
        DiscourseSizeAction.create!(
          character_id: character_1.id,
          user_id: user.id,
          action_type: "grow",
          size_change: 0.0001,
          start_offset: -169.9999,
          end_offset: -169.9998,
          duration_minutes: 60,
          start_time: Time.now,
          end_time: Time.now + 60.minutes,
        )

      character_1.update!(base_size: 30.48)

      character_1.reload
      action.reload

      expect(character_1.current_size).to be_within(1e-6).of(0.0001)
      expect(character_1.base_size + character_1.target_offset).to be_within(1e-6).of(0.0001)
      expect(character_1.base_size + action.start_offset).to be_within(1e-6).of(0.0001)
      expect(character_1.base_size + action.end_offset).to be_within(1e-6).of(0.0002)
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

    it "shifts offsets on microscopic base_size changes when character has actions" do
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

      expect(character_1.current_size).to be_within(1e-22).of(1.0e-18)
      expect(character_1.base_size + action.end_offset).to be_within(1e-22).of(1.1e-18)
    end
  end

  describe "subatomic minimum size" do
    it "has MIN_SIZE equal to 1e-35" do
      expect(DiscourseSizeCharacter::MIN_SIZE).to eq(1e-35)
    end

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
  end
end
