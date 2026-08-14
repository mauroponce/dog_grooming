import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "end"]

  copy() {
    const sourceStart = this.startTargets.find((input) => input.value)?.value
    const sourceEnd = this.endTargets.find((input) => input.value)?.value

    this.startTargets.forEach((input) => input.value = sourceStart || input.value)
    this.endTargets.forEach((input) => input.value = sourceEnd || input.value)
  }
}
