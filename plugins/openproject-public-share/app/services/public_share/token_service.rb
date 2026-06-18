# frozen_string_literal: true

module PublicShare
  class TokenService
    # Returns [raw_token, digest]. Raw token is shown once; only digest is stored.
    def generate
      raw    = SecureRandom.urlsafe_base64(32)
      digest = Digest::SHA256.hexdigest(raw)
      [raw, digest]
    end

    # Looks up an active link by raw token using constant-time digest comparison.
    # Returns nil for any bad/expired/revoked/kill-switched token — no information leak.
    def find_active(raw)
      return nil if OpenProject::PublicShare.kill_switch_active?
      return nil if raw.blank?

      digest = Digest::SHA256.hexdigest(raw.to_s)
      link   = ShareLink.find_by(token_digest: digest)
      return nil unless link&.active?

      link
    end
  end
end
