import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]
  static values = { titleSelector: String }

  connect() {
    this.sections = this.linkTargets
      .map((link) => document.querySelector(link.getAttribute("href")))
      .filter(Boolean)

    this.sectionObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) this.activate(entry.target.id)
      })
    }, { rootMargin: "-96px 0px -58% 0px", threshold: 0.01 })

    this.sections.forEach((section) => this.sectionObserver.observe(section))
    this.activate(this.sections[0]?.id)
    this.watchTitleVisibility()
  }

  disconnect() {
    this.sectionObserver?.disconnect()
    this.titleObserver?.disconnect()
  }

  activate(sectionId) {
    if (!sectionId) return

    this.linkTargets.forEach((link) => {
      const active = link.getAttribute("href") === `#${sectionId}`
      link.classList.toggle("border-zinc-950", active)
      link.classList.toggle("text-zinc-950", active)
      link.classList.toggle("border-transparent", !active)
      link.classList.toggle("text-zinc-500", !active)
    })
  }

  watchTitleVisibility() {
    const selector = this.hasTitleSelectorValue ? this.titleSelectorValue : "[data-public-business-title]"
    const title = document.querySelector(selector)

    if (!title) return

    this.setHeaderVisible(title.getBoundingClientRect().bottom <= 0)

    this.titleObserver = new IntersectionObserver((entries) => {
      const entry = entries[0]
      this.setHeaderVisible(!entry.isIntersecting)
    }, { threshold: 0 })

    this.titleObserver.observe(title)
  }

  setHeaderVisible(visible) {
    this.element.classList.toggle("-translate-y-full", !visible)
    this.element.classList.toggle("translate-y-0", visible)
    this.element.classList.toggle("opacity-0", !visible)
    this.element.classList.toggle("opacity-100", visible)
    this.element.classList.toggle("pointer-events-none", !visible)
  }
}
