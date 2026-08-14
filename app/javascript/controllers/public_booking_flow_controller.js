import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.shouldScrollAfterFrameLoad = false
    this.refreshBookingChrome = this.refreshBookingChrome.bind(this)
    this.resizeObserver = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(this.refreshBookingChrome)

    window.addEventListener("resize", this.refreshBookingChrome)
    this.resetHorizontalScroll()
    this.refreshBookingChrome()
  }

  disconnect() {
    window.removeEventListener("resize", this.refreshBookingChrome)
    this.resizeObserver?.disconnect()
  }

  scheduleScroll(event) {
    const trigger = event.target.closest("a, button")
    if (!trigger || !this.element.contains(trigger)) return
    if (!trigger.closest("[data-public-booking-summary], [data-public-booking-mobile-footer]")) return
    if (!this.isProgressAction(trigger)) return

    this.shouldScrollAfterFrameLoad = true
    this.scrollToTop("smooth")
  }

  scrollAfterFrameLoad(event) {
    if (event.target.id !== "booking_flow") return

    requestAnimationFrame(() => {
      this.refreshBookingChrome()
      this.resetHorizontalScroll()

      if (!this.shouldScrollAfterFrameLoad) return

      this.shouldScrollAfterFrameLoad = false
      this.scrollToTop("auto")
    })
  }

  isProgressAction(trigger) {
    return ["Continuar", "Confirmar", "Enviar comprobante"].includes(trigger.textContent.trim())
  }

  scrollToTop(behavior) {
    window.scrollTo({ left: 0, top: 0, behavior })
  }

  resetHorizontalScroll() {
    if (window.scrollX === 0) return

    window.scrollTo({ left: 0, top: window.scrollY, behavior: "auto" })
  }

  refreshBookingChrome() {
    this.resizeObserver?.disconnect()

    const header = this.element.querySelector("[data-public-booking-header]")
    const footer = this.element.querySelector("[data-public-booking-mobile-footer]")

    const observableElements = [header, footer].filter(Boolean)
    observableElements.forEach((element) => this.resizeObserver?.observe(element))

    this.setDimension("--public-booking-header-height", header, 72)
    this.setDimension("--public-booking-footer-height", footer, 0)
  }

  setDimension(variable, element, fallback) {
    const height = Math.ceil(element?.getBoundingClientRect().height || fallback)
    this.element.style.setProperty(variable, `${height}px`)
  }
}
