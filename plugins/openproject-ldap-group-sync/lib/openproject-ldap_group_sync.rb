# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-ldap_group_sync"); that file in turn
# loads the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/ldap_group_sync/version"
require "openproject/ldap_group_sync/engine"
