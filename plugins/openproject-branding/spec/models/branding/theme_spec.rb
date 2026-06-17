# frozen_string_literal: true

require "spec_helper"

RSpec.describe Branding::Theme, type: :model do
  describe "validations" do
    it "is valid with a name" do
      expect(described_class.new(name: "default")).to be_valid
    end

    it "requires a name" do
      theme = described_class.new(name: nil)
      expect(theme).not_to be_valid
      expect(theme.errors[:name]).to be_present
    end

    it "enforces a unique name" do
      described_class.create!(name: "default")
      dup = described_class.new(name: "default")
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to be_present
    end

    it "rejects an unsupported logo content type" do
      theme = described_class.new(name: "default",
                                  logo_blob: "x",
                                  logo_content_type: "application/pdf")
      expect(theme).not_to be_valid
      expect(theme.errors[:logo_content_type]).to be_present
    end

    it "accepts allowed logo content types" do
      %w[image/png image/jpeg image/jpg image/webp image/svg+xml].each do |ct|
        theme = described_class.new(name: "t-#{ct.hash}",
                                    logo_blob: "x",
                                    logo_content_type: ct)
        expect(theme).to be_valid, "expected #{ct} to be allowed"
      end
    end

    it "rejects a logo blob over 1 MB" do
      theme = described_class.new(name: "default",
                                  logo_blob: "a" * (Branding::Theme::MAX_LOGO_BYTES + 1),
                                  logo_content_type: "image/png")
      expect(theme).not_to be_valid
      expect(theme.errors[:logo_blob]).to be_present
    end
  end

  describe "#logo_data_uri" do
    it "returns nil without a blob" do
      expect(described_class.new(name: "default").logo_data_uri).to be_nil
    end

    it "encodes the blob as a base64 data URI" do
      theme = described_class.new(name: "default",
                                  logo_blob: "hello",
                                  logo_content_type: "image/png")
      expect(theme.logo_data_uri)
        .to eq("data:image/png;base64,#{Base64.strict_encode64('hello')}")
    end
  end
end

RSpec.describe Branding::CssCompiler do
  describe ".call" do
    it "emits the primary and accent CSS variables" do
      css = described_class.call(
        "primary_color" => "#123456",
        "accent_color"  => "#abcdef",
        "custom_css"    => ""
      )
      expect(css).to include("--branding-primary: #123456")
      expect(css).to include("--branding-accent: #abcdef")
    end

    it "falls back to defaults for invalid colors" do
      css = described_class.call(
        "primary_color" => "javascript:alert(1)",
        "accent_color"  => "",
        "custom_css"    => ""
      )
      expect(css).to include("--branding-primary: #{described_class::DEFAULT_PRIMARY}")
      expect(css).to include("--branding-accent: #{described_class::DEFAULT_ACCENT}")
    end

    it "strips a closing </style> tag from custom CSS" do
      css = described_class.call("custom_css" => "body{}</style><script>alert(1)</script>")
      expect(css).not_to match(%r{</\s*style}i)
      expect(css).not_to include("<script>")
    end

    it "strips @import rules" do
      css = described_class.call("custom_css" => "@import url('https://evil.example/x.css'); body{}")
      expect(css).not_to match(/@import/i)
    end

    it "strips expression()" do
      css = described_class.call("custom_css" => "div{width:expression(alert(1));}")
      expect(css).not_to match(/expression\s*\(/i)
    end

    it "removes javascript: url() values" do
      css = described_class.call("custom_css" => "div{background:url(javascript:alert(1));}")
      expect(css).not_to match(/javascript:/i)
    end

    it "neutralizes http:// url() schemes but keeps data:/https:" do
      css = described_class.call(
        "custom_css" => "a{background:url(http://evil/x.png)} b{background:url(https://ok/x.png)} c{background:url(data:image/png;base64,AAA)}"
      )
      expect(css).not_to include("http://evil")
      expect(css).to include("https://ok/x.png")
      expect(css).to include("data:image/png;base64,AAA")
    end

    it "applies a safe logo data URI as content" do
      css = described_class.call({}, logo_data_uri: "data:image/png;base64,AAA")
      expect(css).to include('content: url("data:image/png;base64,AAA")')
    end

    it "ignores an unsafe logo URI" do
      css = described_class.call({}, logo_data_uri: "javascript:alert(1)")
      expect(css).not_to include("content: url")
    end
  end
end
