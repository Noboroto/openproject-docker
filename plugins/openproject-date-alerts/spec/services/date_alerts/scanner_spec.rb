# frozen_string_literal: true

require "spec_helper"

# Uses core factories: :user, :work_package, :status (with is_closed),
# :project, available in the OP test harness.
RSpec.describe DateAlerts::Scanner, type: :model do
  subject(:alerts) { described_class.new.each_alert.to_a }

  let(:assignee) { create(:user) }
  let(:open_status)   { create(:status, is_closed: false) }
  let(:closed_status) { create(:status, is_closed: true) }

  def alert_tuples
    alerts.map { |user, wp, kind| [user, wp, kind] }
  end

  context "with a due date inside the default lead window" do
    let!(:work_package) do
      create(:work_package,
             status: open_status,
             assigned_to: assignee,
             due_date: Date.current + 1)
    end

    it "yields a :due alert for the assignee" do
      expect(alert_tuples).to include([assignee, work_package, :due])
    end
  end

  context "with a due date outside the lead window" do
    before do
      create(:work_package,
             status: open_status,
             assigned_to: assignee,
             due_date: Date.current + 30)
    end

    it "does not yield an alert" do
      expect(alert_tuples).to be_empty
    end
  end

  context "when the user disabled due-date alerts" do
    before do
      DateAlerts::AlertPreference.create!(user_id: assignee.id,
                                          due_date_enabled: false,
                                          lead_days: 1)
      create(:work_package, status: open_status,
                            assigned_to: assignee, due_date: Date.current)
    end

    it "is skipped" do
      expect(alert_tuples).to be_empty
    end
  end

  context "with a closed work package due today" do
    before do
      create(:work_package, status: closed_status,
                            assigned_to: assignee, due_date: Date.current)
    end

    it "is skipped (only open WPs are scanned)" do
      expect(alert_tuples).to be_empty
    end
  end

  context "with no assignee" do
    before do
      create(:work_package, status: open_status,
                            assigned_to: nil, due_date: Date.current)
    end

    it "is skipped" do
      expect(alert_tuples).to be_empty
    end
  end

  context "with a start date inside the lead window" do
    let!(:work_package) do
      create(:work_package, status: open_status,
                            assigned_to: assignee, start_date: Date.current + 1)
    end

    it "yields a :start alert" do
      expect(alert_tuples).to include([assignee, work_package, :start])
    end
  end
end
