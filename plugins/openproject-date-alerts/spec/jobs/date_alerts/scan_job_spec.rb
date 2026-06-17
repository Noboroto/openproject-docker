# frozen_string_literal: true

require "spec_helper"

RSpec.describe DateAlerts::ScanJob, type: :job do
  it "delivers a notification through the Notifier for each scanned alert" do
    user = build_stubbed(:user)
    wp   = build_stubbed(:work_package)

    scanner = instance_double(DateAlerts::Scanner)
    allow(DateAlerts::Scanner).to receive(:new).and_return(scanner)
    allow(scanner).to receive(:each_alert).and_yield(user, wp, :due)

    notifier = instance_double(DateAlerts::Notifier, deliver: true)
    expect(DateAlerts::Notifier)
      .to receive(:new).with(user, wp, :due).and_return(notifier)
    expect(notifier).to receive(:deliver)

    described_class.new.perform
  end

  it "re-running on the same day is a no-op for already-sent alerts (idempotent)" do
    user = create(:user)
    wp = create(:work_package, assigned_to: user, due_date: Date.current)
    allow_any_instance_of(WorkPackage).to receive(:visible?).and_return(true)
    allow_any_instance_of(::Notifications::CreateService).to receive(:call)

    expect(::Notifications::CreateService).to receive(:new).once.and_call_original

    described_class.new.perform
    described_class.new.perform # second run must not create a second notification
  end
end
