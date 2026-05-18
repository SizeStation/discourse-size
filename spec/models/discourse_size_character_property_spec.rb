# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSizeCharacterProperty do
  fab!(:user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 100, current_offset: 0, character_type: 'normal') }

  it "saves properties correctly" do
    prop = DiscourseSizeCharacterProperty.create!(
      character: character,
      name: "Tail length",
      property_type: "size",
      value: "50"
    )

    expect(prop.name).to eq("Tail length")
    expect(prop.property_type).to eq("size")
    expect(prop.value).to eq("50")
  end

  it "returns effective_value as value when no animation is active" do
    prop = DiscourseSizeCharacterProperty.create!(
      character: character,
      name: "Notes",
      property_type: "text",
      value: "Strong"
    )

    expect(prop.effective_value).to eq("Strong")
  end

  it "validates property_type inclusion" do
    prop = DiscourseSizeCharacterProperty.new(
      character: character,
      name: "Bad type",
      property_type: "invalid",
      value: "test"
    )

    expect(prop).not_to be_valid
  end
end
