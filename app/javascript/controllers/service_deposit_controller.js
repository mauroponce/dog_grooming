import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "checkbox", "amount" ]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasCheckboxTarget || !this.hasAmountTarget) return

    this.amountTarget.hidden = !this.checkboxTarget.checked
  }
}
