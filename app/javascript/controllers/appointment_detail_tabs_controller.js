import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    const hashTab = this.tabFromHash()
    const selected = this.buttonTargets.find((button) => button.getAttribute("aria-selected") === "true")
    this.show(hashTab || selected?.dataset.tab || this.buttonTargets[0]?.dataset.tab)
  }

  select(event) {
    event.preventDefault()
    this.show(event.currentTarget.dataset.tab)
  }

  show(tab) {
    if (!tab) return

    this.buttonTargets.forEach((button) => {
      const active = button.dataset.tab === tab
      button.setAttribute("aria-selected", active ? "true" : "false")
      button.classList.toggle("bg-ink", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("border-ink", active)
      button.classList.toggle("bg-white", !active)
      button.classList.toggle("text-zinc-700", !active)
      button.classList.toggle("border-zinc-200", !active)
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.tabPanel !== tab)
    })
  }

  tabFromHash() {
    const hash = window.location.hash.replace("#", "")
    return { historial: "history", history: "history" }[hash]
  }
}
