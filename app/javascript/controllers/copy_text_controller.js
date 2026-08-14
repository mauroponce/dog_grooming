import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = { url: String, preserveContent: Boolean, updateTitle: Boolean }

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
    if (!this.hasButtonTarget) return

    if (this.preserveContentValue) {
      if (this.shouldUpdateTitle) this.buttonTarget.title = "Copiado"
      this.buttonTarget.setAttribute("aria-label", "Copiado")
      window.clearTimeout(this.resetTimeout)
      this.resetTimeout = window.setTimeout(() => {
        if (this.shouldUpdateTitle) this.buttonTarget.title = "Copiar"
        this.buttonTarget.setAttribute("aria-label", "Copiar")
      }, 1400)
    } else {
      this.buttonTarget.textContent = "Copiado"
    }

    this.showTooltip("Copiado")
  }

  async copyAndOpen() {
    await this.copy()
    if (this.hasUrlValue && this.urlValue) window.open(this.urlValue, "_blank", "noopener")
  }

  showTooltip(message) {
    const tooltip = this.tooltipElement
    tooltip.textContent = message
    tooltip.classList.add("is-visible")

    window.clearTimeout(this.tooltipTimeout)
    this.tooltipTimeout = window.setTimeout(() => {
      tooltip.classList.remove("is-visible")
    }, 1400)
  }

  get tooltipElement() {
    if (this.tooltip?.isConnected) return this.tooltip

    if (window.getComputedStyle(this.buttonTarget).position === "static") {
      this.buttonTarget.style.position = "relative"
    }

    this.tooltip = document.createElement("span")
    this.tooltip.className = "copy-text-tooltip"
    this.tooltip.setAttribute("role", "status")
    this.buttonTarget.appendChild(this.tooltip)
    return this.tooltip
  }

  get shouldUpdateTitle() {
    return !this.hasUpdateTitleValue || this.updateTitleValue
  }
}
