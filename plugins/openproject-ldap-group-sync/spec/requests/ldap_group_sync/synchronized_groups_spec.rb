# frozen_string_literal: true

require "spec_helper"

# Relies on the OP request-spec harness (`login_as`, core factories).
RSpec.describe "LDAP group sync admin", type: :request do
  let(:admin)  { create(:admin) }
  let(:member) { create(:user) }
  let(:group)  { create(:group) }

  describe "GET index" do
    it "renders for an admin" do
      login_as admin
      get "/admin/ldap_group_sync"
      expect(response).to have_http_status(:ok)
    end

    it "forbids a non-admin" do
      login_as member
      get "/admin/ldap_group_sync"
      expect(response).to have_http_status(:forbidden).or have_http_status(:redirect)
    end
  end

  describe "POST create" do
    before { login_as admin }

    it "creates a mapping" do
      expect do
        post "/admin/ldap_group_sync", params: {
          synchronized_group: {
            ldap_auth_source_id: 1,
            group_id: group.id,
            dn: "cn=devs,dc=example,dc=com",
            sync_users: "1"
          }
        }
      end.to change(LdapGroupSync::SynchronizedGroup, :count).by(1)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "POST sync (Sync now)" do
    before { login_as admin }

    it "enqueues the synchronization job" do
      mapping = LdapGroupSync::SynchronizedGroup.create!(
        ldap_auth_source_id: 1, group:, dn: "cn=devs,dc=example,dc=com"
      )

      expect(LdapGroupSync::SynchronizationJob)
        .to receive(:perform_later).with(synchronized_group_id: mapping.id)

      post "/admin/ldap_group_sync/#{mapping.id}/sync"
      expect(response).to have_http_status(:redirect)
    end
  end
end
