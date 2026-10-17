import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { this.clean() }

  clean() {
    this.element.value = this.element.value.replace(/\D/g, "")
  }
}
