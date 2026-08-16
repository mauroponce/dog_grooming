import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "preview", "fallback"]

  disconnect() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
  }

  preview(event) {
    const file = event.target.files?.[0]
    if (!file || !file.type.startsWith("image/")) return

    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = URL.createObjectURL(file)

    let image = this.previewTarget.querySelector("img")
    if (!image) {
      image = document.createElement("img")
      image.className = "h-full w-full object-cover"
      image.alt = "Vista previa de la foto de perfil"
      this.previewTarget.appendChild(image)
    }

    image.src = this.previewUrl
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
