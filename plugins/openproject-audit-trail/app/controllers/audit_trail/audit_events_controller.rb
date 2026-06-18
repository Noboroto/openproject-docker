# frozen_string_literal: true

require "csv"

module AuditTrail
  # Administration -> Audit trail.
  #
  # Admin-only (OpenProject's built-in `require_admin` — runs BEFORE any data is
  # read or streamed, so the CSV export is authorized before a single row leaves
  # the server). Read-only: there is NO write/update/delete action. Audit events
  # are created exclusively by the Recorder in response to notifications.
  class AuditEventsController < ::ApplicationController
    before_action :require_admin

    layout "admin"

    menu_item :audit_trail

    PER_PAGE = 50
    EXPORT_LIMIT = 50_000 # cap CSV size to avoid unbounded memory use

    def index
      # OpenProject does not bundle Kaminari's `.page/.per`, so paginate with
      # plain limit/offset. The view degrades gracefully (it guards on
      # `respond_to?(:total_pages)`), so no pagination gem is required.
      page = [params[:page].to_i, 1].max
      @events = filtered_scope
                .order(occurred_at: :desc)
                .limit(PER_PAGE)
                .offset((page - 1) * PER_PAGE)
      @event_names = AuditTrail::Recorder::SUBSCRIBED_EVENTS

      respond_to do |format|
        format.html
        format.csv { stream_csv }
      end
    end

    private

    # Builds the filtered, read-only query from sanitized params. Filtering is
    # done with parameterized where clauses (no string interpolation of input).
    def filtered_scope
      scope = AuditEvent.all
      scope = scope.where(event: params[:event]) if params[:event].present?
      scope = scope.where("occurred_at >= ?", parse_time(params[:from])) if params[:from].present?
      scope = scope.where("occurred_at <= ?", parse_time(params[:to])) if params[:to].present?
      scope
    end

    def parse_time(value)
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # Streams the (filtered) audit log as CSV. require_admin has already run as a
    # before_action, so authorization is enforced before any data is read here.
    def stream_csv
      filename = "audit_trail_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"

      headers["Content-Type"] = "text/csv; charset=utf-8"
      headers["Content-Disposition"] = %(attachment; filename="#{filename}")
      # Prevent caching of potentially sensitive audit data.
      headers["Cache-Control"] = "no-store"

      self.response_body = csv_enumerator
    end

    def csv_enumerator
      scope = filtered_scope.order(occurred_at: :desc).limit(EXPORT_LIMIT)

      Enumerator.new do |yielder|
        yielder << CSV.generate_line(csv_header)
        scope.find_each do |event|
          yielder << CSV.generate_line(csv_row(event))
        end
      end
    end

    def csv_header
      %w[occurred_at event actor_id target_type target_id ip_address changes]
    end

    def csv_row(event)
      [
        event.occurred_at&.iso8601,
        event.event,
        event.actor_id,
        event.target_type,
        event.target_id,
        event.ip_address,
        event.changes.to_json
      ]
    end
  end
end
