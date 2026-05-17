# frozen_string_literal: true

require 'rails_helper'

describe DiscourseSizeCharacterProperty do
  fab!(:user)
  fab!(:character) { Fabricate(:discourse_size_character, user: user, base_size: 100, current_offset: 0, character_type: 'freeform') }

  it "calculates link_ratio on save" do
    prop = DiscourseSizeCharacterProperty.create!(
      character: character,
      name: "Tail length",
      property_type: "size",
      value: "50",
      linked_to_size: true
    )
    
    expect(prop.link_ratio).to eq(0.5)
  end

  it "scales effective_value when character size changes" do
    prop = DiscourseSizeCharacterProperty.create!(
      character: character,
      name: "Tail length",
      property_type: "size",
      value: "50",
      linked_to_size: true
    )
    
    character.update!(current_offset: 100) # Size is now 200
    expect(prop.effective_value).to eq(100.0)
  end

  it "does not scale if not linked" do
    prop = DiscourseSizeCharacterProperty.create!(
      character: character,
      name: "Notes",
      property_type: "text",
      value: "Strong",
      linked_to_size: false
    )
    
    character.update!(current_offset: 100)
    expect(prop.effective_value).to eq("Strong")
  end
end
