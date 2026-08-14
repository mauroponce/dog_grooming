import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "preview", "slug"]
  static values = { host: String }

  connect() {
    this.update()
  }

  update() {
    const slug = this.slugify(this.nameTarget.value)
    this.slugTarget.value = slug
    this.previewTarget.textContent = `Enlace: ${this.hostValue}/${slug || "tu-enlace"}`
  }

  slugify(value) {
    return value
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
  }
}
