import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["thumbnail", "modal", "title", "count", "image", "previousButton", "nextButton"]
  static values = { title: String }

  connect() {
    this.index = 0
    this.pageLocked = false
    this.handleKeydown = this.handleKeydown.bind(this)
    this.lockPage()
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    this.unlockPage()
  }

  open(event) {
    event.preventDefault()
    this.index = Number(event.params.index || 0)
    this.render()
    this.modalTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.handleKeydown)
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.close()
  }

  previous(event) {
    event.preventDefault()
    if (this.images.length <= 1) return

    this.index = (this.index - 1 + this.images.length) % this.images.length
    this.render()
  }

  next(event) {
    event.preventDefault()
    if (this.images.length <= 1) return

    this.index = (this.index + 1) % this.images.length
    this.render()
  }

  render() {
    const image = this.images[this.index]
    if (!image) return

    this.titleTarget.textContent = this.titleValue
    this.countTarget.textContent = `${this.index + 1}/${this.images.length}`
    this.imageTarget.src = image.url
    this.imageTarget.alt = image.alt

    const disabled = this.images.length <= 1
    this.previousButtonTarget.disabled = disabled
    this.nextButtonTarget.disabled = disabled
    this.previousButtonTarget.classList.toggle("opacity-40", disabled)
    this.nextButtonTarget.classList.toggle("opacity-40", disabled)
  }

  handleKeydown(event) {
    if (this.modalTarget.classList.contains("hidden")) return

    if (event.key === "Escape") this.close()
    if (event.key === "ArrowLeft") this.previous(event)
    if (event.key === "ArrowRight") this.next(event)
  }

  unlockPage() {
    if (!this.pageLocked) return

    const locks = Math.max(Number(document.documentElement.dataset.publicServiceModalLocks || 1) - 1, 0)
    this.pageLocked = false

    if (locks > 0) {
      document.documentElement.dataset.publicServiceModalLocks = locks
      return
    }

    delete document.documentElement.dataset.publicServiceModalLocks
    document.documentElement.classList.remove("overflow-hidden")
    document.body.classList.remove("overflow-hidden")
  }

  lockPage() {
    if (this.pageLocked) return

    const locks = Number(document.documentElement.dataset.publicServiceModalLocks || 0) + 1
    this.pageLocked = true
    document.documentElement.dataset.publicServiceModalLocks = locks
    document.documentElement.classList.add("overflow-hidden")
    document.body.classList.add("overflow-hidden")
  }

  get images() {
    return this.thumbnailTargets.map((thumbnail) => ({
      url: thumbnail.dataset.publicServiceGalleryUrl,
      alt: thumbnail.dataset.publicServiceGalleryAlt || this.titleValue
    }))
  }
}
