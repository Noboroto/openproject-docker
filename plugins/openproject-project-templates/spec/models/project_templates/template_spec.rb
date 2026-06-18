# frozen_string_literal: true

require "spec_helper"

# Relies on OpenProject's core spec harness + FactoryBot (`create(:project)`).
RSpec.describe ProjectTemplates::Template, type: :model do
  let(:project) { create(:project) }

  it "is valid with a project and a name" do
    template = described_class.new(project:, name: "Template A")
    expect(template).to be_valid
  end

  it "requires a name" do
    template = described_class.new(project:, name: nil)
    expect(template).not_to be_valid
    expect(template.errors[:name]).to be_present
  end

  it "enforces one template per project (unique project_id)" do
    described_class.create!(project:, name: "First")
    dup = described_class.new(project:, name: "Second")
    expect(dup).not_to be_valid
    expect(dup.errors[:project_id]).to be_present
  end

  it "enforces a unique name" do
    described_class.create!(project:, name: "Shared")
    other = described_class.new(project: create(:project), name: "Shared")
    expect(other).not_to be_valid
    expect(other.errors[:name]).to be_present
  end

  it "exposes only public templates via the scope" do
    pub  = described_class.create!(project:, name: "Pub", is_public: true)
    described_class.create!(project: create(:project), name: "Priv", is_public: false)
    expect(described_class.public_templates).to contain_exactly(pub)
  end
end
