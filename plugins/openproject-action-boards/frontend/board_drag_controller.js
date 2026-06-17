// Stimulus controller for the action board drag-drop interaction.
//
// This is the deliberate first-iteration frontend (server-rendered columns +
// a thin controller that issues the PATCH). For a full OpenProject-native
// experience an Angular component would live under frontend/module/ and be
// registered through OP's frontend module system; see
// https://www.openproject.org/docs/development/frontend/
//
// Registration: OpenProject bundles plugin Stimulus controllers through its
// frontend build. VERIFY the controller-registration path against the running
// 17-slim image (the OP asset pipeline expects controllers under a known
// directory / naming convention).
//
// Server contract:
//   PATCH <moveUrlTemplate>  body: { column_id, work_package_id }
//   200 -> move accepted (leave card where dropped)
//   422 -> illegal transition / not permitted (revert card to origin)

import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["card", "dropzone"];
  static values = { moveUrlTemplate: String, csrf: String };

  connect() {
    this.draggedCard = null;
    this.originDropzone = null;

    this.cardTargets.forEach((card) => {
      card.addEventListener("dragstart", (e) => this.onDragStart(e, card));
    });
    this.dropzoneTargets.forEach((zone) => {
      zone.addEventListener("dragover", (e) => e.preventDefault());
      zone.addEventListener("drop", (e) => this.onDrop(e, zone));
    });
  }

  onDragStart(event, card) {
    this.draggedCard = card;
    this.originDropzone = card.closest("[data-board-drag-target='dropzone']");
    event.dataTransfer.effectAllowed = "move";
  }

  async onDrop(event, zone) {
    event.preventDefault();
    if (!this.draggedCard) return;

    const columnId = zone.dataset.columnId;
    const workPackageId = this.draggedCard.dataset.workPackageId;

    // Optimistically move the card; revert on a non-2xx response.
    zone.appendChild(this.draggedCard);

    try {
      const response = await fetch(this.moveUrlTemplateValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfValue,
          Accept: "application/json",
        },
        body: JSON.stringify({ column_id: columnId, work_package_id: workPackageId }),
      });

      if (!response.ok) {
        // 422: workflow/permission rejected the move -> revert.
        if (this.originDropzone) this.originDropzone.appendChild(this.draggedCard);
        const data = await response.json().catch(() => ({}));
        window.alert((data.errors && data.errors.join("\n")) || "Move failed");
      }
    } catch (err) {
      if (this.originDropzone) this.originDropzone.appendChild(this.draggedCard);
    } finally {
      this.draggedCard = null;
      this.originDropzone = null;
    }
  }
}
