# frozen_string_literal: true

require "spec_helper"

# Exercises the real entry points (core notifications and the login hook) rather
# than Recorder#record, because the original bug was wiring: event names core never
# sends and a payload nested one level deeper than the recorder read it.
RSpec.describe "Audit trail wiring", type: :model do
  let(:user) { create(:user) }

  before do
    Setting.plugin_openproject_audit_trail = { "retention_days" => 365, "capture_ip" => false }
  end

  it "subscribes only to event names core defines" do
    core_events = OpenProject::Events.constants.map { |c| OpenProject::Events.const_get(c) }

    expect(AuditTrail::Recorder::NOTIFICATION_EVENTS).to all(satisfy { |name| core_events.include?(name) })
  end

  it "records a member notification sent the way core sends it" do
    member = create(:member, principal: user, project: create(:project), roles: [create(:project_role)])

    expect do
      OpenProject::Notifications.send(OpenProject::Events::MEMBER_CREATED, member:)
    end.to change(AuditTrail::AuditEvent.where(event: "member_created"), :count).by(1)

    expect(AuditTrail::AuditEvent.last).to have_attributes(target_type: "Member", target_id: member.id)
  end

  describe "the :user_logged_in hook" do
    it "records the login with the logged-in user as actor" do
      expect do
        OpenProject::Hook.call_hook(:user_logged_in, user:, request: nil, session: {})
      end.to change(AuditTrail::AuditEvent.where(event: "user_logged_in"), :count).by(1)

      expect(AuditTrail::AuditEvent.last.actor_id).to eq(user.id)
    end

    it "does not raise when recording fails" do
      allow(AuditTrail::AuditEvent).to receive(:create!).and_raise(ActiveRecord::StatementInvalid)

      expect do
        OpenProject::Hook::Listener.subclasses
          .find { |k| k.name == "OpenProject::AuditTrail::Hooks" }
          .instance.user_logged_in(user:, request: nil, session: {})
      end.not_to raise_error
    end
  end
end
