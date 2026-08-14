import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 350 }
  }

  submit() {
    this.element.requestSubmit()
  }

  schedule() {
    window.clearTimeout(this.timeout)
    this.timeout = window.setTimeout(() => this.submit(), this.delayValue)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
  }
}
