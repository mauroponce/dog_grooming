import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "error" ]

  connect() {
    this.submit = this.submit.bind(this)
    this.element.addEventListener("submit", this.submit)
    this.validate(false)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.submit)
  }

  format() {
    const digits = this.inputTarget.value.replace(/\D/g, "").slice(0, 8)
    const groups = [ digits.slice(0, 2), digits.slice(2, 4), digits.slice(4, 8) ].filter(Boolean)
    this.inputTarget.value = groups.join("/")
    this.validate(false)
  }

  validateFromInput() {
    this.validate(true)
  }

  validate(showError = true) {
    const value = this.inputTarget.value.trim()
    const message = this.validationMessage(value)
    const valid = message === ""

    this.inputTarget.setCustomValidity(message)
    this.inputTarget.classList.toggle("is-invalid", !valid && value !== "")
    this.inputTarget.setAttribute("aria-invalid", (!valid && value !== "").toString())

    if (showError && !valid) {
      this.errorTarget.textContent = message
      this.errorTarget.hidden = false
    } else {
      this.errorTarget.textContent = ""
      this.errorTarget.hidden = true
    }

    return valid
  }

  submit(event) {
    if (this.validate(true)) return

    event.preventDefault()
    this.inputTarget.focus()
  }

  validationMessage(value) {
    if (value === "") return ""
    if (!/^\d{2}\/\d{2}\/\d{4}$/.test(value)) return "Ingresá la fecha completa con formato dd/mm/aaaa."

    const [ day, month, year ] = value.split("/").map(Number)
    const date = new Date(year, month - 1, day)
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) return "Ingresá una fecha de nacimiento válida."
    if (date > today) return "La fecha de nacimiento no puede ser futura."

    return ""
  }
}
