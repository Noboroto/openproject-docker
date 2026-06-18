# frozen_string_literal: true

require "spec_helper"

RSpec.describe PdfStyler::TemplateSanitizer do
  describe ".call" do
    it "strips script tags" do
      result = described_class.call('<p>Hello</p><script>alert(1)</script>')
      expect(result).not_to include("<script>")
      expect(result).to include("Hello")
    end

    it "strips onerror handlers" do
      result = described_class.call('<img src="x" onerror="alert(1)">')
      expect(result).not_to include("onerror")
    end

    it "strips javascript: img src" do
      result = described_class.call('<img src="javascript:alert(1)">')
      expect(result).not_to include("javascript:")
    end

    it "strips style tags" do
      result = described_class.call('<style>body{display:none}</style><p>ok</p>')
      expect(result).not_to include("<style>")
      expect(result).to include("ok")
    end

    it "allows https img src" do
      result = described_class.call('<img src="https://example.com/logo.png">')
      expect(result).to include("https://example.com/logo.png")
    end

    it "allows data: img src" do
      result = described_class.call('<img src="data:image/png;base64,abc">')
      expect(result).to include("data:image/png")
    end

    it "returns empty string for blank input" do
      expect(described_class.call(nil)).to eq("")
      expect(described_class.call("")).to eq("")
    end
  end
end
