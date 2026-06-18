# frozen_string_literal: true

require "spec_helper"

RSpec.describe CustomFieldsPlus::FieldOption, type: :model do
  let(:field) { create(:cfp_advanced_field, field_type: :hierarchy) }
  let(:root)  { create(:cfp_field_option, advanced_field: field, label: "Root") }

  describe "tree / parent association" do
    it "allows children" do
      child = create(:cfp_field_option, advanced_field: field, label: "Child", parent: root)
      expect(root.children).to include(child)
    end
  end

  describe "cycle validation" do
    it "prevents self-reference" do
      root.parent_id = root.id
      expect(root).not_to be_valid
      expect(root.errors[:parent_id]).to be_present
    end
  end
end
