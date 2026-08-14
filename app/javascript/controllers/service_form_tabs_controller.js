import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "input"]
  static values = { active: { type: String, default: "basic" } }

  connect() {
    this.update()
  }

  select(event) {
    event.preventDefault()
    this.activeValue = event.currentTarget.dataset.serviceFormTabsTabValue
  }

  activeValueChanged() {
    this.update()
  }

  update() {
    if (this.hasInputTarget) this.inputTarget.value = this.activeValue

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.serviceFormTabsTabValue === this.activeValue
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.serviceFormTabsPanelValue !== this.activeValue
    })
  }
}
