import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "status"]
  static values = { url: String }

  connect() {
    this.draggedItem = null
    this.initialOrder = []
    this.saving = false
  }

  dragStart(event) {
    if (this.saving) {
      event.preventDefault()
      return
    }

    this.draggedItem = event.currentTarget.closest("[data-tutorial-sort-target='item']")
    if (!this.draggedItem) return

    this.initialOrder = this.tutorialIds()
    this.draggedItem.classList.add("is-dragging")
    event.dataTransfer?.setData("text/plain", this.draggedItem.dataset.tutorialId)
    if (event.dataTransfer) event.dataTransfer.effectAllowed = "move"
  }

  dragOver(event) {
    event.preventDefault()
    if (!this.draggedItem || this.saving) return

    const target = event.currentTarget
    if (target === this.draggedItem) return

    const { top, height } = target.getBoundingClientRect()
    const placeBefore = event.clientY < top + (height / 2)

    this.clearDropTargets()
    target.classList.add("is-drop-target")
    if (placeBefore) {
      target.before(this.draggedItem)
    } else {
      target.after(this.draggedItem)
    }
  }

  drop(event) {
    event.preventDefault()
    this.clearDropTargets()

    const tutorialIds = this.tutorialIds()
    if (!this.draggedItem || this.sameOrder(tutorialIds, this.initialOrder)) return

    this.save(tutorialIds)
  }

  dragEnd() {
    this.draggedItem?.classList.remove("is-dragging")
    this.clearDropTargets()
    this.draggedItem = null
  }

  async save(tutorialIds) {
    this.saving = true
    this.setStatus("Guardando orden…")

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ tutorial_ids: tutorialIds })
      })

      if (!response.ok) throw new Error("No se pudo guardar el orden.")

      this.setStatus("Orden guardado.")
    } catch (_error) {
      this.setStatus("No se pudo guardar el orden. Recargando…", "error")
      window.setTimeout(() => window.location.reload(), 700)
    } finally {
      this.saving = false
    }
  }

  tutorialIds() {
    return this.itemTargets.map((item) => item.dataset.tutorialId)
  }

  sameOrder(left, right) {
    return left.length === right.length && left.every((id, index) => id === right[index])
  }

  clearDropTargets() {
    this.itemTargets.forEach((item) => item.classList.remove("is-drop-target"))
  }

  setStatus(message, state = "success") {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = message
    this.statusTarget.dataset.state = state
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
