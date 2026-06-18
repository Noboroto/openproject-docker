# frozen_string_literal: true

require "net/ldap"

module LdapGroupSync
  # Queries an LDAP directory (via Net::LDAP, already a CE dependency) for the
  # members of a given group DN, then maps those LDAP members to OpenProject user
  # ids via their login / mail.
  #
  # Security: never logs bind credentials or full LDAP entries. Only DNs and
  # counts are surfaced. Results are paged and capped.
  class GroupMembershipResolver
    # verify against running 17-slim image: these attribute names mirror CE's
    # LdapAuthSource columns. Confirm the exact accessor names
    # (host/port/account/account_password/base_dn/attr_login/attr_mail/tls_mode)
    # against the running model before relying on them.
    def initialize(ldap_auth_source, max_members: default_max)
      @source = ldap_auth_source
      @max_members = max_members
    end

    # Returns a Set<Integer> of OpenProject user ids that are members of the LDAP
    # group identified by `group_dn`.
    def user_ids_in(group_dn)
      member_dns = member_dns_for(group_dn)
      logins_and_mails = member_dns.first(@max_members).filter_map { |dn| identity_for(dn) }

      logins = logins_and_mails.map { |h| h[:login] }.compact
      mails  = logins_and_mails.map { |h| h[:mail] }.compact

      ids = User.where(login: logins).pluck(:id)
      ids += User.where(mail: mails).pluck(:id) if mails.any?
      ids.to_set
    end

    private

    def default_max
      OpenProject::LdapGroupSync.settings["max_members_per_run"].to_i.clamp(1, 100_000)
    end

    # The DNs listed as members of the group entry (member / uniqueMember).
    def member_dns_for(group_dn)
      entry = connection.search(base: group_dn, scope: Net::LDAP::SearchScope_BaseObject).first
      raise I18n.t(:"ldap_group_sync.errors.ldap_unreachable") if entry.nil? && connection.get_operation_result.code != 0

      return [] if entry.nil?

      (Array(entry[:member]) + Array(entry[:uniquemember])).uniq
    end

    # Resolve a member DN to its login + mail by reading the user entry.
    def identity_for(member_dn)
      entry = connection.search(base: member_dn, scope: Net::LDAP::SearchScope_BaseObject).first
      return nil unless entry

      {
        login: Array(entry[login_attr]).first,
        mail:  Array(entry[mail_attr]).first
      }
    end

    def login_attr
      (@source.respond_to?(:attr_login) && @source.attr_login.presence || "uid").to_sym
    end

    def mail_attr
      (@source.respond_to?(:attr_mail) && @source.attr_mail.presence || "mail").to_sym
    end

    def connection
      @connection ||= begin
        ldap = Net::LDAP.new(
          host: @source.host,
          port: @source.port,
          base: @source.base_dn
        )
        # Bind with the service account credentials stored on the auth source.
        if @source.respond_to?(:account) && @source.account.present?
          ldap.auth(@source.account, @source.account_password)
        end
        raise I18n.t(:"ldap_group_sync.errors.ldap_unreachable") unless ldap.bind

        ldap
      end
    end
  end
end
