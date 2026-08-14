import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "details", "chevron"]

  toggle(event) {
    const button = event.currentTarget
    const rowId = button.dataset.rowId
    const row = this.rowTargets.find((target) => target.dataset.rowId === rowId)
    const details = this.detailsTargets.find((target) => target.dataset.rowId === rowId)
    const chevron = this.chevronTargets.find((target) => target.dataset.rowId === rowId)
    const wasOpen = button.getAttribute("aria-expanded") === "true"

    this.closeAll()

    if (!wasOpen && row && details) {
      row.dataset.expanded = "true"
      details.classList.remove("hidden")
      this.buttonsFor(rowId).forEach((toggleButton) => {
        toggleButton.setAttribute("aria-expanded", "true")
      })
      chevron?.classList.add("rotate-180")
    }
  }

  closeAll() {
    this.rowTargets.forEach((row) => {
      row.dataset.expanded = "false"
    })

    this.detailsTargets.forEach((details) => {
      details.classList.add("hidden")
    })

    this.element.querySelectorAll("[data-action='admin-appointments-table#toggle']").forEach((button) => {
      button.setAttribute("aria-expanded", "false")
    })

    this.chevronTargets.forEach((chevron) => {
      chevron.classList.remove("rotate-180")
    })
  }

  buttonsFor(rowId) {
    return this.element.querySelectorAll(`[data-action='admin-appointments-table#toggle'][data-row-id='${rowId}']`)
  }
}
