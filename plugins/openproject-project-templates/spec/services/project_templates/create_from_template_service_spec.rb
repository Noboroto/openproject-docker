# frozen_string_literal: true

require "spec_helper"

# Exercises the delegation to the core Projects::CopyService and the size guard.
# CopyService is stubbed so the spec does not depend on a full copy run; a
# companion integration spec (not included) would assert real copying.
RSpec.describe ProjectTemplates::CreateFromTemplateService do
  let(:user)         { create(:admin) }
  let(:source)       { create(:project, name: "Source") }
  let(:template)     { ProjectTemplates::Template.create!(project: source, name: "Tpl") }
  let(:new_project)  { create(:project, name: "Clone") }
  let(:attributes)   { { name: "Clone", identifier: "clone" } }

  before do
    Setting.plugin_openproject_project_templates =
      { "max_work_packages" => 2000, "copy_attachments" => false }
  end

  def build_service
    described_class.new(template:, user:, attributes:)
  end

  it "delegates to Projects::CopyService and passes workspace_type: project" do
    copy_service = instance_double(::Projects::CopyService)
    service_result = double(success?: true, result: new_project)

    expect(::Projects::CopyService)
      .to receive(:new).with(user:, source:).and_return(copy_service)
    expect(copy_service).to receive(:call) do |kwargs|
      expect(kwargs[:target_project_params][:workspace_type]).to eq("project")
      expect(kwargs[:target_project_params][:name]).to eq("Clone")
      expect(kwargs[:only]).to include("work_packages", "members", "wiki")
      expect(kwargs[:only]).not_to include("work_package_attachments")
      service_result
    end

    result = build_service.call
    expect(result.success?).to be(true)
    expect(result.project).to eq(new_project)
  end

  it "includes attachments only when the setting is on" do
    Setting.plugin_openproject_project_templates =
      { "max_work_packages" => 2000, "copy_attachments" => true }

    copy_service = instance_double(::Projects::CopyService)
    allow(::Projects::CopyService).to receive(:new).and_return(copy_service)
    expect(copy_service).to receive(:call) do |kwargs|
      expect(kwargs[:only]).to include("work_package_attachments")
      double(success?: true, result: new_project)
    end

    build_service.call
  end

  it "raises TooLargeError when the template exceeds max_work_packages" do
    Setting.plugin_openproject_project_templates =
      { "max_work_packages" => 1, "copy_attachments" => false }
    allow(template).to receive(:work_package_count).and_return(5)

    expect { build_service.call }
      .to raise_error(described_class::TooLargeError)
  end

  it "returns failure with errors when CopyService fails" do
    copy_service = instance_double(::Projects::CopyService)
    failed = double(success?: false,
                    errors: double(full_messages: ["Identifier taken"]))
    allow(::Projects::CopyService).to receive(:new).and_return(copy_service)
    allow(copy_service).to receive(:call).and_return(failed)

    result = build_service.call
    expect(result.success?).to be(false)
    expect(result.errors).to include("Identifier taken")
  end
end
