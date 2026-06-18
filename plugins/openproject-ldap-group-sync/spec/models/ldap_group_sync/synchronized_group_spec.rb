# frozen_string_literal: true

require "spec_helper"

RSpec.describe LdapGroupSync::SynchronizedGroup, type: :model do
  let(:group) { create(:group) }

  def build_mapping(attrs = {})
    described_class.new(
      { ldap_auth_source_id: 1, group:, dn: "cn=devs,ou=groups,dc=example,dc=com" }
        .merge(attrs)
    )
  end

  it "is valid with a source, group and dn" do
    expect(build_mapping).to be_valid
  end

  it "requires a dn" do
    expect(build_mapping(dn: nil)).not_to be_valid
  end

  it "requires an ldap_auth_source_id" do
    expect(build_mapping(ldap_auth_source_id: nil)).not_to be_valid
  end

  it "enforces a unique dn per auth source" do
    build_mapping.save!
    dup = build_mapping
    expect(dup).not_to be_valid
    expect(dup.errors[:dn]).to be_present
  end

  it "allows the same dn on a different auth source" do
    build_mapping.save!
    expect(build_mapping(ldap_auth_source_id: 2)).to be_valid
  end

  describe "privileged-group guardrail" do
    let(:admin_group) { create(:group, lastname: "Administrators") }

    it "rejects mapping an admin-named group without explicit confirmation" do
      mapping = build_mapping(group: admin_group)
      expect(mapping).not_to be_valid
      expect(mapping.errors[:group]).to be_present
    end

    it "permits it when confirmed" do
      mapping = build_mapping(group: admin_group)
      mapping.confirm_privileged = true
      expect(mapping).to be_valid
    end
  end
end
