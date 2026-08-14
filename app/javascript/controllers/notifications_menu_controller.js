import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    this.open ? this.close() : this.show()
  }

  show() {
    this.panelTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
  }

  closeOnOutside(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  closeOnEscape(event) {
    if (event.key !== "Escape") return

    this.close()
    this.buttonTarget.focus()
  }

  get open() {
    return !this.panelTarget.classList.contains("hidden")
  }
}
