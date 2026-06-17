# frozen_string_literal: true

module OpenProject
  module AuthSso
    # Thin, boot-safe accessor over the `op_sso_providers` table used by the
    # OmniAuth middleware initializer. It must never raise during boot — the table
    # may not exist yet (fresh DB before migrate), or the DB may be unreachable
    # during asset precompilation / `assets:precompile`. In those cases it yields
    # nothing so the app still boots (and local-password login keeps working).
    module ProviderRegistry
      module_function

      # Yields each active provider record. Swallows all DB/load errors so a
      # mis-/un-migrated database can never make the instance un-bootable.
      def each_active
        return unless table_ready?

        ::AuthSso::Provider.where(active: true).find_each do |provider|
          yield provider
        end
      rescue StandardError => e
        Rails.logger.warn("[auth_sso] skipping SSO strategy build: #{e.class}: #{e.message}")
        nil
      end

      def table_ready?
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.data_source_exists?(:op_sso_providers)
        end
      rescue StandardError
        false
      end
    end
  end
end
