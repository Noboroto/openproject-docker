# frozen_string_literal: true

require "spec_helper"

RSpec.describe PdfStyler::ExportTemplate, type: :model do
  subject do
    described_class.new(
      name:         "Brand Template",
      font_family:  "Helvetica",
      accent_color: "#1A67A3",
      active:       true
    )
  end

  it { is_expected.to be_valid }

  it "requires name" do
    subject.name = nil
    expect(subject).not_to be_valid
  end

  it "rejects invalid font family" do
    subject.font_family = "Comic Sans"
    expect(subject).not_to be_valid
  end

  it "rejects malformed accent color" do
    subject.accent_color = "red"
    expect(subject).not_to be_valid
  end

  describe ".active" do
    it "returns only active templates" do
      active   = create(:pdf_export_template, active: true)
      inactive = create(:pdf_export_template, active: false)
      expect(described_class.active).to include(active)
      expect(described_class.active).not_to include(inactive)
    end
  end
end
