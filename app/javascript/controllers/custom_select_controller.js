import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "trigger", "menu", "label", "option"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener("click", this.closeOnOutsideClick)
    this.syncFromInput()
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
  }

  toggle(event) {
    event.preventDefault()
    if (this.inputTarget.disabled) return

    this.setOpen(!this.open)
  }

  choose(event) {
    event.preventDefault()
    this.selectOption(event.currentTarget)
    this.setOpen(false)
    this.triggerTarget.focus()
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.setOpen(false)
      this.triggerTarget.focus()
      return
    }

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      this.setOpen(true)
      this.focusAdjacentOption(event.key === "ArrowDown" ? 1 : -1)
      return
    }

    if ((event.key === "Enter" || event.key === " ") && event.target !== this.triggerTarget) {
      event.preventDefault()
      this.selectOption(event.target)
      this.setOpen(false)
      this.triggerTarget.focus()
    }
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.setOpen(false)
  }

  syncFromInput() {
    if (!this.hasInputTarget || !this.hasOptionTarget) return

    const selectedOption = this.optionTargets.find((option) => option.dataset.customSelectValue === this.inputTarget.value) || this.optionTargets[0]
    if (selectedOption) this.updateSelectedOption(selectedOption, false)
    this.triggerTarget.disabled = this.inputTarget.disabled
  }

  selectOption(option) {
    if (!option || !option.dataset) return

    this.updateSelectedOption(option)
  }

  updateSelectedOption(option, dispatchChange = true) {
    this.inputTarget.value = option.dataset.customSelectValue
    this.labelTarget.textContent = option.dataset.customSelectLabel

    this.optionTargets.forEach((item) => {
      const selected = item === option
      item.classList.toggle("is-selected", selected)
      item.setAttribute("aria-selected", selected)
    })

    if (dispatchChange) {
      this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  focusAdjacentOption(direction) {
    const options = this.optionTargets
    if (!options.length) return

    const currentIndex = Math.max(0, options.findIndex((option) => option.classList.contains("is-selected")))
    const nextIndex = (currentIndex + direction + options.length) % options.length
    options[nextIndex].focus()
  }

  get open() {
    return this.hasMenuTarget && !this.menuTarget.hidden
  }

  setOpen(open) {
    if (!this.hasMenuTarget || !this.hasTriggerTarget) return

    this.menuTarget.hidden = !open
    this.triggerTarget.setAttribute("aria-expanded", open)
  }
}
