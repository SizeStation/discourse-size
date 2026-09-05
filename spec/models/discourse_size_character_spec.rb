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
  end
end
