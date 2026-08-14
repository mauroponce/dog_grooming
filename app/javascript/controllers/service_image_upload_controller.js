import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "summary", "preview", "actions", "modal", "modalImage", "modalTitle", "deleteLink"]

  connect() {
    this.sync()
  }

  dragOver(event) {
    event.preventDefault()
    event.currentTarget.classList.add("is-dragging")
  }

  dragLeave(event) {
    event.currentTarget.classList.remove("is-dragging")
  }

  drop(event) {
    event.preventDefault()
    event.currentTarget.classList.remove("is-dragging")
    if (!this.hasInputTarget) return

    const files = Array.from(event.dataTransfer?.files || []).filter((file) => file.type.startsWith("image/"))
    if (files.length === 0) return

    const transfer = new DataTransfer()
    files.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
    this.sync()
  }

  sync() {
    if (!this.hasInputTarget) return

    const files = Array.from(this.inputTarget.files || [])
    const hasPendingFiles = files.length > 0

    if (this.hasActionsTarget) this.actionsTarget.hidden = !hasPendingFiles

    if (!hasPendingFiles) {
      if (this.hasSummaryTarget) this.summaryTarget.textContent = "o hacé click para elegir archivos JPG, PNG o WEBP."
      if (this.hasPreviewTarget) {
        this.previewTarget.innerHTML = ""
        this.previewTarget.hidden = true
      }
      return
    }

    if (this.hasSummaryTarget) {
      this.summaryTarget.textContent = files.length === 1 ? files[0].name : `${files.length} imágenes seleccionadas`
    }

    if (!this.hasPreviewTarget) return

    this.previewTarget.innerHTML = ""
    files.forEach((file) => this.previewFile(file))
    this.previewTarget.hidden = false
  }

  openSavedImage(event) {
    event.preventDefault()

    const trigger = event.currentTarget
    if (this.hasModalImageTarget) {
      this.modalImageTarget.src = trigger.dataset.serviceImageUrl || ""
      this.modalImageTarget.alt = trigger.dataset.serviceImageName || "Imagen del servicio"
    }
    if (this.hasModalTitleTarget) this.modalTitleTarget.textContent = trigger.dataset.serviceImageName || "Imagen del servicio"
    if (this.hasDeleteLinkTarget) this.deleteLinkTarget.href = trigger.dataset.serviceImageDeleteUrl || "#"

    if (this.hasModalTarget) this.modalTarget.showModal()
  }

  closeSavedImage() {
    if (!this.hasModalTarget) return

    this.modalTarget.close()
  }

  closeSavedImageOnBackdrop(event) {
    if (event.target === this.modalTarget) this.closeSavedImage()
  }

  previewFile(file) {
    if (!file.type.startsWith("image/")) return

    const url = URL.createObjectURL(file)
    const figure = document.createElement("figure")
    figure.className = "service-image-card service-image-pending-card"

    const image = document.createElement("img")
    image.src = url
    image.alt = file.name
    image.onload = () => URL.revokeObjectURL(url)

    const caption = document.createElement("figcaption")
    caption.className = "service-image-filename"
    caption.textContent = file.name

    figure.appendChild(image)
    figure.appendChild(caption)
    this.previewTarget.appendChild(figure)
  }
}
