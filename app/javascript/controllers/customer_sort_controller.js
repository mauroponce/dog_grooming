import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "trigger", "menu", "label", "option"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.closeOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  toggle() {
    this.setOpen(!this.open)
  }

  choose(event) {
    const option = event.currentTarget

    this.inputTarget.value = option.dataset.customerSortValue
    this.labelTarget.textContent = option.dataset.customerSortLabel
    this.optionTargets.forEach((item) => {
      const selected = item === option
      item.classList.toggle("is-selected", selected)
      item.setAttribute("aria-selected", selected)
    })
    this.setOpen(false)
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  keydown(event) {
    if (event.key !== "Escape") return

    this.setOpen(false)
    this.triggerTarget.focus()
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.setOpen(false)
  }

  get open() {
    return !this.menuTarget.hidden
  }

  setOpen(open) {
    this.menuTarget.hidden = !open
    this.triggerTarget.setAttribute("aria-expanded", open)
  }
}
