import { Controller } from "@hotwired/stimulus"

const OPEN_EYE_PATHS = '<path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6-9.5-6Z" /><circle cx="12" cy="12" r="2.75" />'
const CLOSED_EYE_PATHS = '<path d="M4 12c2.2 3 4.9 4.5 8 4.5s5.8-1.5 8-4.5" /><path d="m8 15.5-1 2.5M12 16.5V20m4-4.5 1 2.5" />'

export default class extends Controller {
  static targets = ["input", "button", "icon", "showIcon", "hideIcon"]
  static values = { showLabel: String, hideLabel: String }

  connect() {
    this.sync()
  }

  toggle() {
    this.inputTarget.type = this.visible ? "password" : "text"
    this.sync()
  }

  sync() {
    this.buttonTarget.setAttribute("aria-pressed", this.visible.toString())
    this.buttonTarget.setAttribute("aria-label", this.visible ? this.hideLabelValue : this.showLabelValue)
    this.buttonTarget.title = this.visible ? this.hideLabelValue : this.showLabelValue

    if (this.hasIconTarget) {
      this.iconTarget.innerHTML = this.visible ? CLOSED_EYE_PATHS : OPEN_EYE_PATHS
      return
    }

    this.showIconTarget.hidden = this.visible
    this.hideIconTarget.hidden = !this.visible
  }

  get visible() {
    return this.inputTarget.type === "text"
  }
}
