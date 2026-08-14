import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = window.setTimeout(() => this.close(), 10000)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
    window.clearTimeout(this.removeTimeout)
  }

  close() {
    window.clearTimeout(this.timeout)
    this.element.classList.add("translate-x-3", "opacity-0")
    this.removeTimeout = window.setTimeout(() => this.element.remove(), 220)
  }
}
