# frozen_string_literal: true

module AuditTrail
  # Translates an ActiveSupport::Notifications event + payload into an immutable
  # AuditEvent row. Stateless; safe to call from any thread/subscriber.
  #
  # Security: NEVER persist secrets. Every payload's change set is run through
  # `scrub` which drops password/token/secret-shaped keys before storage.
  class Recorder
    # Centralized list of subscribed event names. Keeping them here (not scattered
    # in the engine) makes it a single place to adjust when verifying against the
    # running image.
    #
    # VERIFY against running 17-slim image: confirm these exact names are what OP
    # publishes. OpenProject sends events through `OpenProject::Notifications`,
    # which forwards to ActiveSupport::Notifications. Likely candidates below;
    # an event that is never published simply never produces a row (no error).
    #
    #   member.created / member.updated / member.destroyed   # role/membership changes  -- VERIFY
    #   project.deleted                                       # project deletion          -- VERIFY
    #   user.activated                                        # account activation        -- VERIFY
    #   user.logged_in / user.logged_out                      # auth events               -- VERIFY (names uncertain)
    #
    # If OP namespaces events (e.g. "members.created" plural, or symbol constants
    # under OpenProject::Events), update this constant accordingly.
    SUBSCRIBED_EVENTS = %w[
      member.created
      member.updated
      member.destroyed
      project.deleted
      user.activated
      user.logged_in
      user.logged_out
    ].freeze

    # Keys (case-insensitive, substring match) whose values must never be stored.
    SENSITIVE_KEY_PATTERNS = %w[
      password hashed_password salt secret token api_key auth_source_token
      private_key otp
    ].freeze

    # ActiveSupport::Notifications subscriber object. Using an object (rather than
    # a block) lets the engine identify and unsubscribe stale listeners across
    # dev reloads without double-recording.
    class Listener
      def call(name, _started, _finished, _unique_id, payload)
        Recorder.new.record(event: name, payload: payload || {})
      rescue StandardError => e
        # Auditing must never break the originating request.
        Rails.logger.error("[audit_trail] failed to record #{name}: #{e.message}")
      end
    end

    def record(event:, payload:)
      target = extract_target(payload)

      AuditEvent.create!(
        event: event.to_s,
        actor_id: current_actor_id,
        target_type: target&.class&.base_class&.name,
        target_id: (target.id if target.respond_to?(:id)),
        changes: scrub(extract_changes(payload)),
        ip_address: (client_ip if capture_ip?),
        occurred_at: Time.current
      )
    end

    private

    # Best-effort resolution of the audited subject from common payload shapes.
    def extract_target(payload)
      return nil unless payload.is_a?(Hash)

      payload[:target] || payload[:project] || payload[:member] ||
        payload[:user] || payload[:model] || payload[:record]
    end

    # Best-effort resolution of a change set (Hash) from common payload shapes.
    def extract_changes(payload)
      return {} unless payload.is_a?(Hash)

      raw = payload[:changes] || payload[:saved_changes] || {}
      raw.respond_to?(:to_h) ? raw.to_h : {}
    end

    # Recursively drop sensitive keys at any nesting level.
    def scrub(hash)
      return {} unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), acc|
        next if sensitive?(key)

        acc[key] = value.is_a?(Hash) ? scrub(value) : value
      end
    end

    def sensitive?(key)
      k = key.to_s.downcase
      SENSITIVE_KEY_PATTERNS.any? { |pat| k.include?(pat) }
    end

    def current_actor_id
      user = (User.current if defined?(User) && User.respond_to?(:current))
      user&.logged? ? user.id : nil
    rescue StandardError
      nil
    end

    def capture_ip?
      ActiveModel::Type::Boolean.new.cast(
        OpenProject::AuditTrail.settings["capture_ip"]
      )
    end

    # VERIFY against running 17-slim image: OP stores the current request's client
    # IP in RequestStore[:client_ip] in several code paths. Wrapped so a missing
    # store degrades to nil rather than raising.
    def client_ip
      return RequestStore[:client_ip] if defined?(RequestStore) && RequestStore.exist?(:client_ip)

      nil
    rescue StandardError
      nil
    end
  end
end
