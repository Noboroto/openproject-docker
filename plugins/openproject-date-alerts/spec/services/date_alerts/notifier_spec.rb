# frozen_string_literal: true

require "spec_helper"

RSpec.describe DateAlerts::Notifier, type: :model do
  let(:user) { create(:user) }
  let(:work_package) do
    create(:work_package, assigned_to: user, due_date: Date.current)
  end

  before do
    # Default to visible; individual examples override.
    allow(work_package).to receive(:visible?).with(user).and_return(true)
  end

  describe "#deliver" do
    it "creates a notification with the due-date reason and records the day" do
      create_service = instance_double(::Notifications::CreateService, call: true)
      expect(::Notifications::CreateService)
        .to receive(:new).with(user:).and_return(create_service)
      expect(create_service)
        .to receive(:call)
        .with(hash_including(recipient: user,
                             resource: work_package,
                             reason: :date_alert_due_date,
                             read_ian: false))

      expect(described_class.new(user, work_package, :due).deliver).to be(true)
      expect(
        DateAlerts::SentAlert.sent_today?(
          user, DateAlerts::SentAlert.key_for(work_package, :due)
        )
      ).to be(true)
    end

    it "is idempotent: a second same-day deliver does not notify again" do
      allow_any_instance_of(::Notifications::CreateService).to receive(:call)
      DateAlerts::SentAlert.create!(
        user_id: user.id,
        alert_key: DateAlerts::SentAlert.key_for(work_package, :due),
        sent_on: Date.current
      )

      expect(::Notifications::CreateService).not_to receive(:new)
      expect(described_class.new(user, work_package, :due).deliver).to be(false)
    end

    it "never notifies about a work package the user cannot see" do
      allow(work_package).to receive(:visible?).with(user).and_return(false)

      expect(::Notifications::CreateService).not_to receive(:new)
      expect(described_class.new(user, work_package, :due).deliver).to be(false)
    end

    it "sends an email only when the user opted in" do
      allow_any_instance_of(::Notifications::CreateService).to receive(:call)
      DateAlerts::AlertPreference.create!(user_id: user.id, email: true, lead_days: 1)

      mail = double(deliver_later: true)
      expect(DateAlerts::Mailer).to receive(:alert).with(user, work_package, :due).and_return(mail)

      described_class.new(user, work_package, :due).deliver
    end
  end
end
