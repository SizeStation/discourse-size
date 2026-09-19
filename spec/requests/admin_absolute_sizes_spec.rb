# frozen_string_literal: true

require "rails_helper"

describe DiscourseSize::AdminController do
  fab!(:admin)
  fab!(:user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 170.0) }

  before do
    freeze_time Time.zone.now.change(usec: 0)
    SiteSetting.discourse_size_enabled = true
  end

  describe "#update_character" do
    it "rejects non-admin current-size overrides" do
      sign_in(user)

      put "/size/admin/characters/#{character.id}.json", params: { current_size: 1e-25 }

      expect(response.status).to eq(403)
      expect(character.reload.current_size).to eq(170.0)
      expect(character.discourse_size_actions).to be_empty
    end

    it "preserves a huge-to-tiny override through a later admin sync" do
      sign_in(admin)
      put "/size/admin/characters/#{character.id}.json",
          params: {
            current_size: DiscourseSizeCharacter::MAX_SIZE,
          }
      expect(response.status).to eq(200)

      put "/size/admin/characters/#{character.id}.json", params: { current_size: 1e-25 }

      expect(response.status).to eq(200)
      expect(response.parsed_body["character"]["discourse_size_character"]["current_size"]).to eq(
        1e-25,
      )
      action = character.discourse_size_actions.order(:id).last
      expect(action).to have_attributes(
        start_size: DiscourseSizeCharacter::MAX_SIZE,
        end_size: 1e-25,
        size_change: 1e-25 - DiscourseSizeCharacter::MAX_SIZE,
        start_offset: DiscourseSizeCharacter::MAX_SIZE - character.base_size,
        end_offset: 1e-25 - character.base_size,
        effect_type: "static",
        effect_amount: 1e-25,
      )

      post "/size/admin/characters/#{character.id}/sync.json"

      expect(response.status).to eq(200)
      expect(character.reload.current_size).to eq(1e-25)
      expect(character.target_size).to eq(1e-25)
      expect(action.reload.end_size).to eq(1e-25)
    end

    it "clamps to the minimum and supports a later microscopic growth override" do
      sign_in(admin)
      minimum = DiscourseSizeCharacter::MIN_SIZE

      put "/size/admin/characters/#{character.id}.json", params: { current_size: 0 }

      expect(response.status).to eq(200)
      expect(character.reload.current_size).to eq(minimum)

      put "/size/admin/characters/#{character.id}.json", params: { current_size: minimum * 2 }

      expect(response.status).to eq(200)
      expect(character.reload.current_size).to eq(minimum * 2)
      expect(character.discourse_size_actions.order(:id).last).to have_attributes(
        action_type: "grow",
        start_size: minimum,
        end_size: minimum * 2,
        size_change: minimum,
      )
    end

    it "replaces set-size animations without changing property animations" do
      sign_in(admin)
      character.discourse_size_character_properties.create!(
        name: "Strength",
        property_type: "number",
        value: "10",
      )
      trigger =
        character.discourse_size_character_triggers.create!(
          name: "Animate",
          js_code: 'character.setSize(340, 60); character.setProperty("Strength", 20, 60);',
        )
      expect(DiscourseSize::TriggerExecutor.execute(character, trigger.name, user)[:success]).to eq(
        true,
      )
      height_action = character.discourse_size_actions.find_by!(action_type: "set_size")
      property_action = character.discourse_size_actions.find_by!(action_type: "property_change")
      property_attributes = property_action.attributes
      freeze_time 30.seconds.from_now

      put "/size/admin/characters/#{character.id}.json", params: { current_size: 1e-25 }

      expect(response.status).to eq(200)
      expect(DiscourseSizeAction.exists?(height_action.id)).to eq(false)
      expect(property_action.reload.attributes).to eq(property_attributes)
      expect(character.reload.current_size).to eq(1e-25)
      expect(character.discourse_size_actions.order(:id).last.start_size).to eq(255.0)
      freeze_time 1.minute.from_now
      expect(character.current_size).to eq(1e-25)
    end

    it "keeps a simultaneous base-size edit and current-size override absolute" do
      sign_in(admin)

      put "/size/admin/characters/#{character.id}.json",
          params: {
            base_size: 200.0,
            current_size: 1e-25,
          }

      expect(response.status).to eq(200)
      expect(character.reload.base_size).to eq(200.0)
      expect(character.current_size).to eq(1e-25)
      expect(character.target_size).to eq(1e-25)
      expect(character.discourse_size_actions.sole.end_offset).to eq(1e-25 - 200.0)
    end
  end

  describe "#sync_character" do
    it "finishes queued set-size animations at their tiny absolute endpoint" do
      sign_in(admin)
      trigger =
        character.discourse_size_character_triggers.create!(
          name: "Resize",
          js_code:
            "character.setSize(#{DiscourseSizeCharacter::MAX_SIZE}); character.setSize(1e-25, 60);",
        )
      expect(DiscourseSize::TriggerExecutor.execute(character, trigger.name, user)[:success]).to eq(
        true,
      )

      post "/size/admin/characters/#{character.id}/sync.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["character"]["discourse_size_character"]["current_size"]).to eq(
        1e-25,
      )
      expect(character.reload.current_size).to eq(1e-25)
      expect(character.target_size).to eq(1e-25)
      expect(character.discourse_size_actions.where("end_time > ?", Time.current)).to be_empty
    end
  end
end
