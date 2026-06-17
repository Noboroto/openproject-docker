# frozen_string_literal: true

module DateAlerts
  # Scans open work packages and yields each [user, work_package, kind] tuple
  # whose start/due date falls within the assignee's configured lead window.
  #
  # Visibility and same-day idempotency are intentionally NOT handled here —
  # the Notifier owns those concerns. The Scanner only decides "is this date
  # within range and does the user want this kind of alert".
  class Scanner
    Alert = Struct.new(:user, :work_package, :kind)

    # @yieldparam user [User]
    # @yieldparam work_package [WorkPackage]
    # @yieldparam kind [Symbol] :start or :due
    def each_alert
      return enum_for(:each_alert) unless block_given?

      scan(:due, :due_date) { |*args| yield(*args) }
      scan(:start, :start_date) { |*args| yield(*args) }
    end

    private

    # `WorkPackage.open` scopes to non-closed statuses. We further require an
    # assignee and a present date. find_each batches to keep this O(n) scan from
    # loading every WP into memory (see README "Performance").
    #
    # verify against running 17-slim image: `WorkPackage.open` is the core scope
    # for "not closed"; confirm it exists (fall back to joining statuses where
    # is_closed = false if the scope name differs).
    def scan(kind, date_column)
      base_scope
        .where.not(date_column => nil)
        .find_each do |work_package|
          assignee = work_package.assigned_to
          next if assignee.nil?

          pref = AlertPreference.for(assignee)
          next unless enabled?(pref, kind)

          date = work_package.public_send(date_column)
          next unless date <= Date.current + pref.lead_days.days

          yield(assignee, work_package, kind)
        end
    end

    def base_scope
      WorkPackage.open.where.not(assigned_to_id: nil)
    end

    def enabled?(pref, kind)
      kind == :due ? pref.due_date_enabled : pref.start_date_enabled
    end
  end
end
