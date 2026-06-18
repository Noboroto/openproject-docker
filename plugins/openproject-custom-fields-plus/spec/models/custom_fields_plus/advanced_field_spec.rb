# frozen_string_literal: true

require "spec_helper"

RSpec.describe CustomFieldsPlus::AdvancedField, type: :model do
  describe "validations" do
    it "is valid with name and field_type" do
      field = described_class.new(name: "Priority Tags", field_type: :multi_list)
      expect(field).to be_valid
    end

    it "requires name" do
      field = described_class.new(field_type: :multi_list)
      expect(field).not_to be_valid
      expect(field.errors[:name]).to be_present
    end

    it "requires field_type" do
      field = described_class.new(name: "Tags")
      expect(field).not_to be_valid
    end
  end

  describe "enum field_type" do
    it "has four types" do
      expect(described_class.field_types.keys).to match_array(
        %w[multi_list hierarchy multi_user multi_version]
      )
    end
  end
end
