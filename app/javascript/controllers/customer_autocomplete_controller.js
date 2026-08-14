import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "menu", "status"]
  static values = {
    url: String,
    emptyText: { type: String, default: "No encontramos resultados." },
    minLength: { type: Number, default: 2 }
  }

  connect() {
    this.abortController = null
    this.debounceTimer = null
    this.results = []
    this.selectedIndex = -1
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.handleDocumentClick)
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick)
    window.clearTimeout(this.debounceTimer)
    this.abortController?.abort()
  }

  input() {
    const query = this.query
    window.clearTimeout(this.debounceTimer)

    if (query.length < this.minLengthValue) {
      this.clear()
      return
    }

    this.debounceTimer = window.setTimeout(() => this.search(query), 220)
  }

  focus() {
    if (this.results.length > 0) this.show()
  }

  keydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.hide()
      return
    }

    if (!this.isOpen || this.options.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, this.options.length - 1)
      this.highlight()
      return
    }

    if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this.highlight()
      return
    }

    if (event.key === "Enter") {
      event.preventDefault()
      const option = this.options[this.selectedIndex] || this.options[0]
      if (option) this.openResult(option)
    }
  }

  search(query) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)

    fetch(url.toString(), {
      headers: { Accept: "application/json" },
      signal: this.abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error("Customer autocomplete request failed")
        return response.json()
      })
      .then((json) => this.render(json.results || []))
      .catch((error) => {
        if (error.name !== "AbortError") this.clear()
      })
  }

  render(results) {
    this.results = results
    this.selectedIndex = -1
    this.menuTarget.innerHTML = ""

    if (results.length === 0) {
      this.renderEmpty()
      return
    }

    results.forEach((result, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.setAttribute("role", "option")
      button.id = `${this.inputTarget.id}_option_${index}`
      button.dataset.customerAutocompleteOption = "true"
      button.dataset.url = result.url
      button.className = "flex w-full items-center gap-3 border-b border-zinc-100 px-4 py-3 text-left transition last:border-b-0 hover:bg-zinc-50"
      button.innerHTML = `
        <span class="grid h-10 w-10 shrink-0 place-items-center rounded-2xl bg-brand-600 text-xs font-bold text-white">${this.escape(result.initials || "HT")}</span>
        <span class="min-w-0 flex-1">
          <span class="block truncate text-sm font-bold text-zinc-950">${this.escape(result.name || "Cliente")}</span>
          <span class="mt-0.5 block truncate text-xs font-semibold text-zinc-500">${this.escape(result.subtitle || "")}</span>
        </span>
        <span class="hidden shrink-0 rounded-full bg-zinc-100 px-2.5 py-1 text-[10px] font-bold text-zinc-500 sm:inline-flex">${this.escape(result.meta || "")}</span>
      `
      button.addEventListener("click", () => this.openResult(button))
      this.menuTarget.appendChild(button)
    })

    this.statusTarget.textContent = `${results.length} resultado${results.length === 1 ? "" : "s"}`
    this.show()
  }

  renderEmpty() {
    this.menuTarget.innerHTML = `
      <div class="px-4 py-4 text-sm font-semibold text-zinc-500">
        ${this.escape(this.emptyTextValue)}
      </div>
    `
    this.statusTarget.textContent = this.emptyTextValue
    this.show()
  }

  openResult(option) {
    const url = option.dataset.url
    if (url) window.location.assign(url)
  }

  highlight() {
    this.options.forEach((option, index) => {
      const selected = index === this.selectedIndex
      option.classList.toggle("bg-brand-50", selected)
      option.setAttribute("aria-selected", selected ? "true" : "false")
    })

    const selectedOption = this.options[this.selectedIndex]
    if (selectedOption) this.inputTarget.setAttribute("aria-activedescendant", selectedOption.id)
  }

  show() {
    this.menuTarget.classList.remove("hidden")
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  hide() {
    this.menuTarget.classList.add("hidden")
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.selectedIndex = -1
  }

  clear() {
    this.results = []
    this.menuTarget.innerHTML = ""
    this.statusTarget.textContent = ""
    this.hide()
  }

  handleDocumentClick(event) {
    if (!this.element.contains(event.target)) this.hide()
  }

  escape(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;")
  }

  get query() {
    return this.inputTarget.value.trim()
  }

  get options() {
    return Array.from(this.menuTarget.querySelectorAll("[data-customer-autocomplete-option]"))
  }

  get isOpen() {
    return !this.menuTarget.classList.contains("hidden")
  }
}
