# frozen_string_literal: true

require "spec_helper"

RSpec.describe CustomFieldsPlus::ScopeResolver do
  let(:user)    { create(:user) }
  let(:project) { create(:project) }

  subject { described_class.new(field, user, project) }

  describe "#visible?" do
    context "when no scope restrictions" do
      let(:field) { create(:cfp_advanced_field, scope_project_ids: [], scope_group_ids: []) }

      it { is_expected.to be_visible }
    end

    context "when project-scoped to another project" do
      let(:other) { create(:project) }
      let(:field) { create(:cfp_advanced_field, scope_project_ids: [other.id]) }

      it { is_expected.not_to be_visible }
    end

    context "when project-scoped to this project" do
      let(:field) { create(:cfp_advanced_field, scope_project_ids: [project.id]) }

      it { is_expected.to be_visible }
    end

    context "when group-scoped and user not in group" do
      let(:group) { create(:group) }
      let(:field) { create(:cfp_advanced_field, scope_group_ids: [group.id]) }

      it { is_expected.not_to be_visible }
    end
  end
end
