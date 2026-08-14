import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dateToggle", "dateFields", "weeklyToggle", "weeklyFields", "day"]

  connect() {
    this.toggleDates()
    this.toggleWeekly()
    this.dayTargets.forEach((day) => this.updateDay(day))
  }

  toggleDates() {
    if (!this.hasDateToggleTarget || !this.hasDateFieldsTarget) return

    this.dateFieldsTarget.hidden = !this.dateToggleTarget.checked
  }

  toggleWeekly() {
    if (!this.hasWeeklyToggleTarget || !this.hasWeeklyFieldsTarget) return

    this.weeklyFieldsTarget.hidden = !this.weeklyToggleTarget.checked
  }

  toggleDay(event) {
    this.updateDay(event.currentTarget.closest("[data-service-availability-target='day']"))
  }

  addInterval(event) {
    event.preventDefault()
    const day = event.currentTarget.closest("[data-service-availability-target='day']")
    if (!day) return

    this.appendInterval(day)
    this.updateRemoveButtons(day)
  }

  removeInterval(event) {
    event.preventDefault()
    const day = event.currentTarget.closest("[data-service-availability-target='day']")
    const interval = event.currentTarget.closest("[data-service-availability-interval]")
    if (!day || !interval) return

    if (this.intervalsFor(day).length > 1) interval.remove()
    this.updateRemoveButtons(day)
  }

  updateDay(day) {
    if (!day) return

    const active = this.dayCheckbox(day)?.checked
    const unavailable = day.querySelector("[data-service-availability-unavailable]")
    const fields = day.querySelector("[data-service-availability-day-fields]")

    if (unavailable) unavailable.hidden = active
    if (fields) fields.hidden = !active

    if (active && this.intervalsFor(day).length === 0) this.appendInterval(day)
    this.updateRemoveButtons(day)
  }

  appendInterval(day, start = "09:00", end = "18:00") {
    const template = day.querySelector("[data-service-availability-template]")
    const container = this.intervalsContainer(day)
    if (!template || !container) return

    const index = Number(day.dataset.nextIndex || 0)
    const wrapper = document.createElement("div")
    wrapper.innerHTML = template.innerHTML.replaceAll("__INDEX__", index)
    const interval = wrapper.firstElementChild
    const selects = interval.querySelectorAll("select")

    if (selects[0]) selects[0].value = start
    if (selects[1]) selects[1].value = end

    container.appendChild(interval)
    day.dataset.nextIndex = String(index + 1)
  }

  updateRemoveButtons(day) {
    const intervals = this.intervalsFor(day)
    const removable = intervals.length > 1

    intervals.forEach((interval) => {
      const button = interval.querySelector(".service-availability-remove")
      if (button) button.hidden = !removable
    })
  }

  intervalsFor(day) {
    return Array.from(day.querySelectorAll("[data-service-availability-interval]"))
  }

  intervalsContainer(day) {
    return day.querySelector("[data-service-availability-intervals]")
  }

  dayCheckbox(day) {
    return day.querySelector("[data-service-availability-day-checkbox]")
  }
}
