# frozen_string_literal: true

require "spec_helper"

RSpec.describe LdapGroupSync::SynchronizeService, type: :model do
  let(:group)        { create(:group) }
  let(:existing)     { create(:user) }
  let(:newcomer)     { create(:user) }
  let(:mapping) do
    LdapGroupSync::SynchronizedGroup.new(
      ldap_auth_source_id: 1, group:, dn: "cn=devs,dc=example,dc=com"
    )
  end

  before do
    allow(mapping.group).to receive(:users).and_return(User.where(id: existing.id))
    allow(User).to receive(:system).and_return(create(:user))
  end

  def resolver_returning(ids)
    instance_double(LdapGroupSync::GroupMembershipResolver, user_ids_in: ids.to_set)
  end

  def stub_groups_services
    add = instance_double("Groups::AddUsersService", call: double(success?: true))
    remove = instance_double("Groups::RemoveUsersService", call: double(success?: true))
    stub_const("Groups::AddUsersService", Class.new { define_method(:initialize) { |*, **| } })
    allow(Groups::AddUsersService).to receive(:new).and_return(add)
    stub_const("Groups::RemoveUsersService", Class.new { define_method(:initialize) { |*, **| } })
    allow(Groups::RemoveUsersService).to receive(:new).and_return(remove)
    [add, remove]
  end

  it "adds users present in LDAP but not in the group" do
    add, = stub_groups_services
    resolver = resolver_returning([existing.id, newcomer.id])

    expect(add).to receive(:call).with(ids: [newcomer.id])
    result = described_class.new(mapping, resolver:).call

    expect(result[:added]).to eq(1)
    expect(result[:removed]).to eq(0)
  end

  it "removes orphaned members when remove_orphaned_memberships is true" do
    allow(OpenProject::LdapGroupSync).to receive(:settings)
      .and_return("remove_orphaned_memberships" => true)
    _add, remove = stub_groups_services
    resolver = resolver_returning([]) # nobody in LDAP -> existing is orphaned

    expect(remove).to receive(:call).with(ids: [existing.id])
    result = described_class.new(mapping, resolver:).call

    expect(result[:removed]).to eq(1)
  end

  it "skips removals when remove_orphaned_memberships is false" do
    allow(OpenProject::LdapGroupSync).to receive(:settings)
      .and_return("remove_orphaned_memberships" => false)
    _add, remove = stub_groups_services
    resolver = resolver_returning([])

    expect(remove).not_to receive(:call)
    result = described_class.new(mapping, resolver:).call

    expect(result[:removed]).to eq(0)
  end
end
