# frozen_string_literal: true

require "spec_helper"

RSpec.describe PlaceholderUsers::ConvertToUserService do
  let(:admin) { create(:admin) }
  let(:placeholder) do
    PlaceholderUsers::PlaceholderUser.create!(name: "Designer slot")
  end

  subject(:service) do
    described_class.new(placeholder,
                        login: "real.user",
                        mail: "real.user@example.com",
                        current_user: admin)
  end

  it "requires a login" do
    result = described_class
             .new(placeholder, login: "", mail: nil, current_user: admin)
             .call
    expect(result.success?).to be(false)
  end

  it "promotes the placeholder to a real User preserving the id" do
    original_id = placeholder.id

    result = service.call

    expect(result.success?).to be(true)
    expect(result.user).to be_a(::User)
    expect(result.user.id).to eq(original_id)
    expect(::User.exists?(id: original_id)).to be(true)
  end

  it "preserves work package assignments because the id is unchanged" do
    # The id never changes, so any work_packages.assigned_to_id pointing at the
    # placeholder now resolves to the promoted real user automatically.
    original_id = placeholder.id
    service.call
    expect(::Principal.find(original_id)).to be_a(::User)
  end
end
