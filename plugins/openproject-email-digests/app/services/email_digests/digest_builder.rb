# frozen_string_literal: true

module EmailDigests
  # Composes and sends one user's digest from their pending queue items, then
  # marks them sent. Idempotent: the items are scoped + flagged, so a re-run
  # finds nothing pending.
  #
  # SECURITY: even though items were visibility-filtered at enqueue time, the
  # builder re-checks `work_package.visible?(user)` at send time — permissions
  # may have changed between capture and delivery (IDOR / stale-access safety).
  class DigestBuilder
    def initialize(user, frequency:)
      @user = user
      @frequency = frequency.to_sym
    end

    def call
      pending = DigestItem.pending.for_user(@user).includes(:work_package).to_a
      return false if pending.empty?

      visible, hidden = pending.partition { |item| visible?(item) }

      DigestMailer.digest(@user, visible, frequency: @frequency).deliver_later if visible.any?

      # Mark ALL pending (visible + hidden) as sent so suppressed items are not
      # re-queued forever; hidden ones are simply dropped from this digest.
      ids = (visible + hidden).map(&:id)
      DigestItem.where(id: ids).update_all(sent: true) if ids.any?

      visible.any?
    end

    private

    def visible?(item)
      wp = item.work_package
      wp.present? && wp.visible?(@user)
    end
  end
end
