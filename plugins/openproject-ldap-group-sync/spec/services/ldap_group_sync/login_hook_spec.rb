# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenProject::LdapGroupSync::Hooks, type: :model do
  subject(:hook) { described_class.instance }

  let(:local_user) { create(:user) }
  let(:ldap_user) { create(:user).tap { |u| allow(u).to receive(:ldap_auth_source_id).and_return(1) } }

  def enable_login_sync(enabled)
    allow(OpenProject::LdapGroupSync).to receive(:settings).and_return("sync_on_login" => enabled)
  end

  before { allow(LdapGroupSync::SynchronizationJob).to receive(:perform_later) }

  it "enqueues a sync for an LDAP login" do
    enable_login_sync(true)
    hook.user_logged_in(user: ldap_user, request: nil, session: {})

    expect(LdapGroupSync::SynchronizationJob).to have_received(:perform_later).with(user_id: ldap_user.id)
  end

  it "skips local users" do
    enable_login_sync(true)
    hook.user_logged_in(user: local_user, request: nil, session: {})

    expect(LdapGroupSync::SynchronizationJob).not_to have_received(:perform_later)
  end

  it "skips when sync_on_login is off" do
    enable_login_sync(false)
    hook.user_logged_in(user: ldap_user, request: nil, session: {})

    expect(LdapGroupSync::SynchronizationJob).not_to have_received(:perform_later)
  end

  it "never lets an enqueue failure break the login" do
    enable_login_sync(true)
    allow(LdapGroupSync::SynchronizationJob).to receive(:perform_later).and_raise(StandardError)

    expect { hook.user_logged_in(user: ldap_user, request: nil, session: {}) }.not_to raise_error
  end
end
