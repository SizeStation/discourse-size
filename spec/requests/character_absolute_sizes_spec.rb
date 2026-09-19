# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSize::CharactersController do
  fab!(:user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 170.0) }

  before do
    freeze_time Time.zone.now.change(usec: 0)
    SiteSetting.discourse_size_enabled = true
    sign_in(user)
  end

  describe "#update" do
    it "edits a normal character's absolute current size without changing its base or old history" do
      character.update_size(DiscourseSizeCharacter::MAX_SIZE, user)
      original_action = character.discourse_size_actions.sole
      original_attributes = original_action.attributes

      put "/size/characters/#{character.id}.json",
          params: {
            name: "Tiny character",
            current_size: 1e-25,
          }

      expect(response.status).to eq(200)
      payload = response.parsed_body["character"]["discourse_size_character"]
      expect(payload).to include(
        "base_size" => 170.0,
        "current_size" => 1e-25,
        "target_size" => 1e-25,
      )
      expect(original_action.reload.attributes).to eq(original_attributes)
      expect(character.reload.current_size).to eq(1e-25)
      expect(character.discourse_size_actions.order(:id).last).to have_attributes(
        start_size: DiscourseSizeCharacter::MAX_SIZE,
        end_size: 1e-25,
      )
    end

    it "leaves the queue untouched when only other profile fields change" do
      character.add_queued_action(
        action_type: "set_size",
        effect_type: "static",
        effect_amount: 1e-25,
        size_change: 0,
        duration_minutes: 10,
        user_id: user.id,
      )
      original_actions = character.discourse_size_actions.map(&:attributes)

      put "/size/characters/#{character.id}.json", params: { name: "New name" }

      expect(response.status).to eq(200)
      expect(character.discourse_size_actions.reload.map(&:attributes)).to eq(original_actions)
      expect(character.reload.target_size).to eq(1e-25)
    end

    it "rejects direct size edits on game characters" do
      character.update!(character_type: "game")

      put "/size/characters/#{character.id}.json", params: { current_size: 1e-25 }

      expect(response.status).to eq(400)
      expect(character.reload.current_size).to eq(170)
      expect(character.discourse_size_actions).to be_empty
    end
  end
end
