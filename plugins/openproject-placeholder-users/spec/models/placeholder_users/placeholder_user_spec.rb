# frozen_string_literal: true

require "spec_helper"

RSpec.describe PlaceholderUsers::PlaceholderUser do
  subject(:placeholder) { described_class.new(name: "Designer slot") }

  it "stores its label as the name" do
    expect(placeholder.name).to eq("Designer slot")
  end

  it "is an STI subtype of Principal with a distinct, namespaced type" do
    expect(placeholder).to be_a(::Principal)
    # MUST NOT reuse core's Enterprise-gated "PlaceholderUser" STI value.
    expect(placeholder.class.name).to eq("PlaceholderUsers::PlaceholderUser")
  end

  describe "authentication is structurally impossible" do
    it "is never active for authentication" do
      expect(placeholder.active_for_authentication?).to be(false)
    end

    it "rejects any password check" do
      expect(placeholder.check_password?("anything")).to be(false)
    end

    it "ignores password assignment" do
      placeholder.password = "secret123"
      expect(placeholder.password).to be_nil
    end

    it "has no usable login or mail" do
      placeholder.login = "ghost"
      placeholder.mail  = "ghost@example.com"
      expect(placeholder.login).to be_nil
      expect(placeholder.mail).to be_nil
    end

    it "reports as not logged" do
      expect(placeholder.logged?).to be(false)
    end
  end
end
