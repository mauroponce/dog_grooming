import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "tab", "panel", "input", "phone" ]
  static values = { active: String }

  connect() {
    this.hashChanged = this.hashChanged.bind(this)
    window.addEventListener("hashchange", this.hashChanged)
    this.activeValue = this.sectionForHash() || this.activeValue
    this.update()
  }

  disconnect() {
    window.removeEventListener("hashchange", this.hashChanged)
  }

  select(event) {
    event.preventDefault()
    const tab = event.currentTarget
    this.activeValue = tab.dataset.customerEditorTabsTabValue

    if (tab.href && new URL(tab.href).hash !== window.location.hash) {
      window.history.pushState({}, "", tab.href)
    }
  }

  activeValueChanged() {
    this.update()
  }

  update() {
    const active = this.activeValue || "personal"

    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.customerEditorTabsTabValue === active
      tab.classList.toggle("is-active", selected)
      tab.setAttribute("aria-selected", selected.toString())
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.customerEditorTabsPanelValue !== active
    })

    if (this.hasInputTarget) this.inputTarget.value = active
  }

  hashChanged() {
    const section = this.sectionForHash()
    if (section && section !== this.activeValue) this.activeValue = section
  }

  sectionForHash() {
    const anchor = window.location.hash.replace(/^#/, "")
    const tab = this.tabTargets.find((item) => item.dataset.customerEditorTabsAnchorValue === anchor)

    return tab?.dataset.customerEditorTabsTabValue
  }

}
