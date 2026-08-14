import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "indicator"]
  static values = { frameId: String, preserveScroll: Boolean }

  connect() {
    this.beforeCache = this.beforeCache.bind(this)
    document.addEventListener("turbo:before-cache", this.beforeCache)
    this.hide()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  start(event) {
    if (event.type === "turbo:before-fetch-request") {
      const isFormRequest = this.hasFormTarget && event.target === this.formTarget
      const frameId = this.hasFrameIdValue ? this.frameIdValue : "customers_results"
      const isFrameRequest = event.target?.id === frameId && this.samePageRequest(event)
      if (!isFormRequest && !isFrameRequest) return
    }

    this.rememberScrollPosition()
    this.indicatorTarget.classList.add("is-visible")
  }

  stop(event) {
    if (event.type === "turbo:frame-load") {
      const frameId = this.hasFrameIdValue ? this.frameIdValue : "customers_results"
      if (event.target.id !== frameId) return
    }

    this.hide()
    this.restoreScrollPosition()
  }

  beforeCache() {
    this.hide()
  }

  hide() {
    if (this.hasIndicatorTarget) this.indicatorTarget.classList.remove("is-visible")
  }

  rememberScrollPosition() {
    if (!this.preserveScrollValue) return

    this.scrollPosition = { left: window.scrollX, top: window.scrollY }
  }

  samePageRequest(event) {
    const url = event.detail?.url || event.target?.src
    if (!url) return true

    try {
      return new URL(url, window.location.href).pathname === window.location.pathname
    } catch (_error) {
      return true
    }
  }

  restoreScrollPosition() {
    if (!this.preserveScrollValue || !this.scrollPosition) return

    const { left, top } = this.scrollPosition
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => window.scrollTo({ left, top, behavior: "auto" }))
    })
  }
}
