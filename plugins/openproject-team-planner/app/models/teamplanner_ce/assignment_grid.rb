# frozen_string_literal: true

module TeamplannerCe
  # Plain-old-Ruby-object that turns AssignmentQuery#rows into a renderable grid:
  # an ordered list of day columns plus, per assignee, a list of positioned bars
  # (offset + span measured in day-columns) for the ERB template.
  #
  # No DB access here — purely presentational geometry. Kept separate from the
  # query so it is trivially unit-testable.
  class AssignmentGrid
    Bar = Struct.new(:work_package, :offset, :span, keyword_init: true)
    Row = Struct.new(:assignee, :bars, keyword_init: true)

    attr_reader :from, :to

    # @param rows [Hash{User => Array<WorkPackage>}] from AssignmentQuery#rows
    def initialize(from:, to:, rows:)
      @from = from
      @to = to
      @rows = rows
    end

    # Ordered list of Date objects, one per visible day-column.
    def days
      @days ||= (@from..@to).to_a
    end

    def day_count
      days.size
    end

    # @return [Array<Row>] one per assignee, each with positioned bars.
    def grid_rows
      @rows.map do |assignee, work_packages|
        Row.new(assignee:, bars: build_bars(work_packages))
      end
    end

    def empty?
      @rows.empty?
    end

    private

    def build_bars(work_packages)
      work_packages.map { |wp| build_bar(wp) }.compact
    end

    # Clamp the WP interval to the visible window, then express it as a 0-based
    # column offset and an inclusive span (>= 1).
    def build_bar(work_package)
      starts = work_package.start_date || work_package.due_date
      ends   = work_package.due_date   || work_package.start_date
      return nil if starts.nil? || ends.nil?

      clamped_start = [starts, @from].max
      clamped_end   = [ends, @to].min
      return nil if clamped_end < clamped_start

      offset = (clamped_start - @from).to_i
      span   = (clamped_end - clamped_start).to_i + 1
      Bar.new(work_package:, offset:, span:)
    end
  end
end
