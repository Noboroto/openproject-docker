# frozen_string_literal: true

# Standard OpenProject plugin entry point. OpenProject requires the file whose
# name matches the gem name ("openproject-email_digests"); that file in turn
# loads the Rails engine which performs the ActsAsOpEngine registration.
require "openproject/email_digests/version"
require "openproject/email_digests/engine"
