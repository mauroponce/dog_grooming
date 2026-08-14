import { Controller } from "@hotwired/stimulus"

const PRESETS = {
  any: { label: "En cualquier momento", start: "00:00", end: "23:55" },
  morning: { label: "Mañana", start: "06:00", end: "12:00" },
  afternoon: { label: "Tarde", start: "12:00", end: "18:00" },
  night: { label: "Noche", start: "18:00", end: "23:55" }
}

export default class extends Controller {
  static targets = [
    "rows",
    "row",
    "template",
    "modal",
    "preset",
    "modalStart",
    "modalEnd",
    "currentPeriod",
    "currentStart",
    "currentEnd",
    "currentLabel"
  ]

  connect() {
    this.currentRow = null
    this.hideModal()
    this.rowTargets.forEach((row) => this.refreshRowLabel(row))
  }

  add(event) {
    event.preventDefault()

    const fragment = this.templateTarget.content.cloneNode(true)
    this.rowsTarget.appendChild(fragment)
    const row = this.rowTargets[this.rowTargets.length - 1]
    this.refreshRowLabel(row)
    row.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  open(event) {
    event.preventDefault()

    this.currentRow = event.currentTarget.closest("[data-waitlist-preferences-target='row']")
    this.currentPeriodTarget.value = this.periodInput.value || "night"
    this.currentStartTarget.value = this.startInput.value || PRESETS.night.start
    this.currentEndTarget.value = this.endInput.value || PRESETS.night.end
    this.currentLabelTarget.value = this.labelInput.value || PRESETS.night.label
    this.modalStartTarget.value = this.currentStartTarget.value
    this.modalEndTarget.value = this.currentEndTarget.value
    this.updatePresetButtons(this.currentPeriodTarget.value)
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("grid")
  }

  choosePreset(event) {
    event.preventDefault()

    const period = event.currentTarget.dataset.period
    const preset = PRESETS[period]
    if (!preset) return

    this.currentPeriodTarget.value = period
    this.currentLabelTarget.value = preset.label
    this.currentStartTarget.value = preset.start
    this.currentEndTarget.value = preset.end
    this.modalStartTarget.value = preset.start
    this.modalEndTarget.value = preset.end
    this.updatePresetButtons(period)
  }

  syncCustomWindow() {
    this.currentPeriodTarget.value = "custom"
    this.currentStartTarget.value = this.modalStartTarget.value
    this.currentEndTarget.value = this.modalEndTarget.value
    this.currentLabelTarget.value = `${this.modalStartTarget.value} a ${this.modalEndTarget.value}`
    this.updatePresetButtons("custom")
  }

  apply(event) {
    event.preventDefault()
    if (!this.currentRow) return

    this.periodInput.value = this.currentPeriodTarget.value
    this.startInput.value = this.currentStartTarget.value
    this.endInput.value = this.currentEndTarget.value
    this.labelInput.value = this.currentLabelTarget.value
    this.refreshRowLabel(this.currentRow)
    this.hideModal()
  }

  remove(event) {
    event.preventDefault()
    if (!this.currentRow) return

    if (this.rowTargets.length > 1) {
      this.currentRow.remove()
    } else {
      this.periodInput.value = "any"
      this.startInput.value = PRESETS.any.start
      this.endInput.value = PRESETS.any.end
      this.labelInput.value = PRESETS.any.label
      this.refreshRowLabel(this.currentRow)
    }
    this.hideModal()
  }

  close(event) {
    event.preventDefault()
    this.hideModal()
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) this.hideModal()
  }

  get periodInput() {
    return this.currentRow.querySelector("[data-waitlist-period]")
  }

  get startInput() {
    return this.currentRow.querySelector("[data-waitlist-start]")
  }

  get endInput() {
    return this.currentRow.querySelector("[data-waitlist-end]")
  }

  get labelInput() {
    return this.currentRow.querySelector("[data-waitlist-label]")
  }

  refreshRowLabel(row) {
    const label = row.querySelector("[data-waitlist-time-label]")
    const hiddenLabel = row.querySelector("[data-waitlist-label]")
    if (label && hiddenLabel) label.textContent = hiddenLabel.value || PRESETS.night.label
  }

  updatePresetButtons(activePeriod) {
    this.presetTargets.forEach((button) => {
      const active = button.dataset.period === activePeriod
      button.classList.toggle("bg-brand-600", active)
      button.classList.toggle("text-white", active)
      button.classList.toggle("border-brand-600", active)
      button.classList.toggle("border-zinc-200", !active)
      button.classList.toggle("bg-white", !active)
      button.classList.toggle("text-zinc-950", !active)
    })
  }

  hideModal() {
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("grid")
    this.currentRow = null
  }
}
