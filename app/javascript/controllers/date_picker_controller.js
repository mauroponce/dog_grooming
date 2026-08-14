import { Controller } from "@hotwired/stimulus"

const MONTH_NAMES = [
  "Enero",
  "Febrero",
  "Marzo",
  "Abril",
  "Mayo",
  "Junio",
  "Julio",
  "Agosto",
  "Septiembre",
  "Octubre",
  "Noviembre",
  "Diciembre"
]

const WEEKDAY_NAMES = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

export default class extends Controller {
  static targets = ["display", "value", "calendar"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.positionCalendar = this.positionCalendar.bind(this)
    this.selectedDate = this.parseISODate(this.valueTarget.value)
    this.viewDate = this.selectedDate || new Date()
    this.mountFloatingCalendar()
    this.syncDisplay()

    document.addEventListener("click", this.closeOnOutsideClick)
    window.addEventListener("resize", this.positionCalendar)
    window.addEventListener("scroll", this.positionCalendar, true)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    window.removeEventListener("resize", this.positionCalendar)
    window.removeEventListener("scroll", this.positionCalendar, true)
    this.restoreCalendar()
  }

  open(event) {
    event?.preventDefault()
    this.syncViewDate()
    this.renderCalendar()
    this.calendarTarget.hidden = false
    this.displayTarget.setAttribute("aria-expanded", "true")
    this.positionCalendar()
  }

  toggle(event) {
    event?.preventDefault()

    if (this.calendarTarget.hidden) this.open()
    else this.close()
  }

  close() {
    this.calendarTarget.hidden = true
    this.displayTarget.setAttribute("aria-expanded", "false")
  }

  keydown(event) {
    if (event.key === "Tab") return

    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
      return
    }

    if (["Enter", " ", "ArrowDown"].includes(event.key)) {
      event.preventDefault()
      this.open()
      return
    }

    event.preventDefault()
  }

  preventManualInput(event) {
    event.preventDefault()
    this.open()
  }

  previousMonth() {
    this.viewDate = new Date(this.viewDate.getFullYear(), this.viewDate.getMonth() - 1, 1)
    this.renderCalendar()
    this.positionCalendar()
  }

  nextMonth() {
    this.viewDate = new Date(this.viewDate.getFullYear(), this.viewDate.getMonth() + 1, 1)
    this.renderCalendar()
    this.positionCalendar()
  }

  selectDate(event) {
    const date = this.parseISODate(event.currentTarget.dataset.datePickerDate)
    if (!date) return

    this.selectedDate = date
    this.valueTarget.value = this.isoDate(date)
    this.displayTarget.value = this.formatDisplayDate(date)
    this.displayTarget.setCustomValidity("")
    this.valueTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.displayTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.displayTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
  }

  today() {
    const today = this.startOfDay(new Date())
    const minDate = this.minDate()
    const maxDate = this.maxDate()
    const date = minDate && today < minDate ? minDate : maxDate && today > maxDate ? maxDate : today

    this.selectedDate = date
    this.viewDate = date
    this.valueTarget.value = this.isoDate(date)
    this.displayTarget.value = this.formatDisplayDate(date)
    this.displayTarget.setCustomValidity("")
    this.valueTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.displayTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.displayTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
  }

  clear() {
    this.selectedDate = null
    this.valueTarget.value = ""
    this.displayTarget.value = ""
    this.valueTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.valueTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.displayTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.displayTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
  }

  renderCalendar() {
    const year = this.viewDate.getFullYear()
    const month = this.viewDate.getMonth()
    const firstDay = new Date(year, month, 1)
    const firstWeekdayIndex = (firstDay.getDay() + 6) % 7
    const firstVisibleDay = 1 - firstWeekdayIndex
    const selectedISO = this.selectedDate ? this.isoDate(this.selectedDate) : ""
    const todayISO = this.isoDate(new Date())
    const minDate = this.minDate()
    const maxDate = this.maxDate()

    const days = Array.from({ length: 42 }, (_, index) => {
      const date = new Date(year, month, firstVisibleDay + index)
      const iso = this.isoDate(date)
      const outsideMonth = date.getMonth() !== month
      const disabled = (minDate && date < minDate) || (maxDate && date > maxDate)
      const classes = [
        "settings-date-picker-day",
        outsideMonth ? "is-outside" : "",
        iso === selectedISO ? "is-selected" : "",
        iso === todayISO ? "is-today" : ""
      ].filter(Boolean).join(" ")

      return `<button type="button" class="${classes}" data-date-picker-date="${iso}" data-action="date-picker#selectDate" ${disabled ? "disabled" : ""}>${date.getDate()}</button>`
    }).join("")

    this.calendarTarget.innerHTML = `
      <div class="settings-date-picker-header">
        <button type="button" class="settings-date-picker-nav" data-action="date-picker#previousMonth" aria-label="Mes anterior">‹</button>
        <p class="settings-date-picker-title">${MONTH_NAMES[month]} ${year}</p>
        <button type="button" class="settings-date-picker-nav" data-action="date-picker#nextMonth" aria-label="Mes siguiente">›</button>
      </div>
      <div class="settings-date-picker-weekdays">
        ${WEEKDAY_NAMES.map((day) => `<span>${day}</span>`).join("")}
      </div>
      <div class="settings-date-picker-grid">${days}</div>
      <div class="settings-date-picker-footer">
        <button type="button" data-action="date-picker#clear">Limpiar</button>
        <button type="button" data-action="date-picker#today">Hoy</button>
      </div>
    `
  }

  syncDisplay() {
    this.displayTarget.value = this.selectedDate ? this.formatDisplayDate(this.selectedDate) : ""
    this.displayTarget.setAttribute("aria-expanded", "false")
  }

  syncViewDate() {
    this.selectedDate = this.parseISODate(this.valueTarget.value)
    const minDate = this.minDate()
    const maxDate = this.maxDate()
    const baseDate = this.selectedDate || this.viewDate || new Date()

    if (minDate && baseDate < minDate) {
      this.viewDate = minDate
    } else if (maxDate && baseDate > maxDate) {
      this.viewDate = maxDate
    } else {
      this.viewDate = baseDate
    }
  }

  mountFloatingCalendar() {
    this.calendarOriginalParent = this.calendarTarget.parentElement
    this.calendarOriginalNextSibling = this.calendarTarget.nextSibling
    document.body.appendChild(this.calendarTarget)
  }

  restoreCalendar() {
    this.close()
    this.calendarTarget.removeAttribute("style")
    if (!this.calendarOriginalParent) return

    if (this.calendarOriginalNextSibling?.parentNode === this.calendarOriginalParent) {
      this.calendarOriginalParent.insertBefore(this.calendarTarget, this.calendarOriginalNextSibling)
    } else {
      this.calendarOriginalParent.appendChild(this.calendarTarget)
    }
  }

  positionCalendar() {
    if (this.calendarTarget.hidden) return

    const rect = this.displayTarget.getBoundingClientRect()
    const spacing = 8
    const viewportPadding = 12
    const width = Math.min(Math.max(rect.width, 292), window.innerWidth - viewportPadding * 2)
    const left = Math.min(Math.max(rect.left, viewportPadding), window.innerWidth - width - viewportPadding)
    const estimatedHeight = 360
    const availableBelow = window.innerHeight - rect.bottom - spacing - viewportPadding
    const availableAbove = rect.top - spacing - viewportPadding
    const openAbove = availableBelow < estimatedHeight && availableAbove > availableBelow

    Object.assign(this.calendarTarget.style, {
      bottom: openAbove ? `${window.innerHeight - rect.top + spacing}px` : "auto",
      left: `${left}px`,
      position: "fixed",
      right: "auto",
      top: openAbove ? "auto" : `${rect.bottom + spacing}px`,
      width: `${width}px`,
      zIndex: "2147483000"
    })
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target) && !this.calendarTarget.contains(event.target)) this.close()
  }

  minDate() {
    return this.parseISODate(this.valueTarget.min)
  }

  maxDate() {
    return this.parseISODate(this.valueTarget.max)
  }

  parseISODate(value) {
    if (!value) return null

    const [year, month, day] = value.split("-").map((part) => Number.parseInt(part, 10))
    if (!year || !month || !day) return null

    return new Date(year, month - 1, day)
  }

  isoDate(date) {
    return [
      date.getFullYear(),
      String(date.getMonth() + 1).padStart(2, "0"),
      String(date.getDate()).padStart(2, "0")
    ].join("-")
  }

  formatDisplayDate(date) {
    return [
      String(date.getDate()).padStart(2, "0"),
      String(date.getMonth() + 1).padStart(2, "0"),
      date.getFullYear()
    ].join("/")
  }

  startOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate())
  }
}
