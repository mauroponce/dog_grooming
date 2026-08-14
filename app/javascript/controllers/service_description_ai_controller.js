import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "category", "description", "button", "status"]
  static values = { url: String }

  async generate() {
    const serviceName = this.nameTarget.value.trim()

    if (!serviceName) {
      this.showStatus("Ingresá el nombre del servicio para generar la descripción.", true)
      this.nameTarget.focus()
      return
    }

    this.setLoading(true)
    this.showStatus("Generando descripción...", false)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({
          service_name: serviceName,
          service_category_id: this.categoryTarget.value,
          category_name: this.selectedCategoryName()
        })
      })
      const payload = await response.json()

      if (!response.ok) throw new Error(payload.error || "No pudimos generar la descripción.")

      this.descriptionTarget.value = payload.description || ""
      this.descriptionTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.descriptionTarget.dispatchEvent(new Event("change", { bubbles: true }))
      this.showStatus("Descripción generada. Podés editarla antes de guardar.", false)
    } catch (error) {
      this.showStatus(error.message, true)
    } finally {
      this.setLoading(false)
    }
  }

  selectedCategoryName() {
    return this.categoryTarget.selectedOptions[0]?.textContent?.trim() || ""
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  setLoading(loading) {
    this.buttonTarget.disabled = loading
    this.buttonTarget.querySelector("span").textContent = loading ? "Generando..." : "Generar"
  }

  showStatus(message, error) {
    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
    this.statusTarget.classList.toggle("is-error", error)
  }
}
