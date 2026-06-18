# frozen_string_literal: true

module PdfStyler
  # Renders work packages to a styled PDF using Prawn (pure Ruby, no binary deps).
  # Sanitized template HTML is used for cover/header/footer text — never executed.
  class RenderService
    MAX_WPS = 200

    def initialize(template, work_packages, project)
      @template       = template
      @work_packages  = Array(work_packages).first(MAX_WPS)
      @project        = project
    end

    def call
      require "prawn"
      require "prawn/table"
      pdf = Prawn::Document.new(
        page_size:   "A4",
        page_layout: :portrait,
        margin:      [60, 50, 60, 50]
      )

      render_cover(pdf)
      render_work_packages(pdf)

      pdf.render
    end

    private

    def render_cover(pdf)
      cover_text = sanitized(@template.cover_html)

      pdf.font(@template.font_family || "Helvetica")

      # Project name + template name as cover heading
      pdf.text @project.name, size: 24, style: :bold, color: accent
      pdf.move_down 10
      pdf.text @template.name, size: 14, color: "444444"
      pdf.move_down 20

      pdf.text cover_text, size: 11 unless cover_text.blank?

      pdf.start_new_page
    end

    def render_work_packages(pdf)
      pdf.text "Work Packages", size: 16, style: :bold
      pdf.move_down 10

      data = [%w[ID Subject Status Done%]] + @work_packages.map { |wp|
        [
          "##{wp.id}",
          wp.subject.to_s.truncate(80),
          wp.status&.name.to_s,
          "#{wp.done_ratio}%"
        ]
      }

      pdf.table(data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(0).background_color = accent
        row(0).text_color       = "FFFFFF"
        columns(0).width = 50
        columns(2).width = 100
        columns(3).width = 60
      end
    end

    def sanitized(html)
      # Strip all tags — for Prawn text-only context.
      ActionView::Base.full_sanitizer.sanitize(TemplateSanitizer.call(html.to_s))
    end

    def accent
      (@template.accent_color || "#1A67A3").delete("#")
    end
  end
end
