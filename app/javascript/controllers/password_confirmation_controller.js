import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "confirmation", "error"]

  connect() {
    this.validate()
  }

  validate() {
    const message = this.errorMessage()

    this.confirmationTarget.setCustomValidity(message)
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.hidden = message === ""
    }
  }

  submit(event) {
    this.validate()

    if (this.confirmationTarget.validationMessage === "") return

    event.preventDefault()
    this.confirmationTarget.reportValidity()
  }

  errorMessage() {
    const password = this.passwordTarget.value
    const confirmation = this.confirmationTarget.value
    if (password === "" && confirmation === "") return ""
    if (password === confirmation) return ""

    return "La confirmación de contraseña no coincide."
  }
}
