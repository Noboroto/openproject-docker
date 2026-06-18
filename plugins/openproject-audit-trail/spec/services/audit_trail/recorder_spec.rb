# frozen_string_literal: true

require "spec_helper"

RSpec.describe AuditTrail::Recorder, type: :model do
  subject(:recorder) { described_class.new }

  before do
    Setting.plugin_openproject_audit_trail = { "retention_days" => 365, "capture_ip" => false }
  end

  describe "#record" do
    it "creates an audit event for a notification" do
      expect do
        recorder.record(event: "project.deleted", payload: {})
      end.to change(AuditTrail::AuditEvent, :count).by(1)

      expect(AuditTrail::AuditEvent.last.event).to eq("project.deleted")
    end

    it "scrubs sensitive keys from the change set" do
      recorder.record(
        event: "member.updated",
        payload: {
          changes: {
            "name" => "Alice",
            "password" => "supersecret",
            "hashed_password" => "abc",
            "auth_source_token" => "xyz",
            "api_key" => "k"
          }
        }
      )

      changes = AuditTrail::AuditEvent.last.changes
      expect(changes).to include("name" => "Alice")
      expect(changes.keys).not_to include("password", "hashed_password", "auth_source_token", "api_key")
    end

    it "scrubs sensitive keys nested inside the change set" do
      recorder.record(
        event: "member.updated",
        payload: { changes: { "credentials" => { "token" => "t", "login" => "bob" } } }
      )

      nested = AuditTrail::AuditEvent.last.changes["credentials"]
      expect(nested).to eq("login" => "bob")
    end

    it "records a nil actor for system events" do
      allow(User).to receive(:current).and_return(nil)
      recorder.record(event: "user.activated", payload: {})
      expect(AuditTrail::AuditEvent.last.actor_id).to be_nil
    end

    it "resolves target_type/target_id from the payload" do
      target = double("Project", id: 42)
      allow(target).to receive(:class).and_return(
        double(base_class: double(name: "Project"))
      )

      recorder.record(event: "project.deleted", payload: { project: target })

      last = AuditTrail::AuditEvent.last
      expect(last.target_type).to eq("Project")
      expect(last.target_id).to eq(42)
    end
  end
end
