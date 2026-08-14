import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "duration", "price", "previewName", "previewDuration", "previewPrice"]

  connect() {
    this.update()
  }

  update() {
    this.previewNameTarget.textContent = this.nameTarget.value || "Tu primer servicio"
    this.previewDurationTarget.textContent = `${this.durationTarget.value || 60} min`
    this.previewPriceTarget.textContent = this.priceTarget.value ? `$${this.priceTarget.value}` : "Consultar"
  }
}
