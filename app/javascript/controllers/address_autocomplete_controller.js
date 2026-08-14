import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "latitude", "longitude", "city", "province", "menu", "mapPanel", "map"]
  static values = {
    url: { type: String, default: "https://photon.komoot.io/api/" }
  }

  connect() {
    this.abortController = null
    this.debounceTimer = null
    this.selectedIndex = -1
    this.map = null
    this.marker = null
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.handleDocumentClick)

    if (this.hasSelectedCoordinates()) {
      this.showSelectedLocation(this.inputTarget.value)
    }
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick)
    window.clearTimeout(this.debounceTimer)
    this.abortController?.abort()
    this.marker?.remove()
    this.map?.remove()
  }

  input() {
    const query = this.inputTarget.value.trim()
    this.clearCoordinates()
    window.clearTimeout(this.debounceTimer)

    if (query.length < 3) {
      this.hide()
      return
    }

    this.debounceTimer = window.setTimeout(() => this.search(query), 300)
  }

  keydown(event) {
    const items = this.menuTarget.querySelectorAll("[data-address-option]")
    if (this.menuTarget.classList.contains("hidden") || items.length === 0) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.hide()
      return
    }

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
      this.highlight(items)
      return
    }

    if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this.highlight(items)
      return
    }

    if (event.key === "Enter" && this.selectedIndex >= 0) {
      event.preventDefault()
      items[this.selectedIndex].click()
    }
  }

  search(query) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue)
    url.searchParams.set("q", query)
    url.searchParams.set("limit", "6")
    url.searchParams.set("countrycode", "AR")

    fetch(url.toString(), { signal: this.abortController.signal })
      .then((response) => {
        if (!response.ok) throw new Error("Photon request failed")
        return response.json()
      })
      .then((json) => this.renderResults(json.features || []))
      .catch((error) => {
        if (error.name !== "AbortError") this.hide()
      })
  }

  renderResults(features) {
    this.menuTarget.innerHTML = ""
    this.selectedIndex = -1

    if (features.length === 0) {
      this.hide()
      return
    }

    features.forEach((feature) => {
      const properties = feature.properties || {}
      if (properties.countrycode && properties.countrycode !== "AR") return

      const coordinates = feature.geometry?.coordinates || []
      const longitude = coordinates[0]
      const latitude = coordinates[1]
      if (latitude === undefined || longitude === undefined) return

      const city = this.cityName(properties)
      const province = this.provinceName(properties)
      if (!province) return

      const label = this.formatFeature(properties)
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.addressOption = "true"
      button.dataset.latitude = latitude
      button.dataset.longitude = longitude
      button.dataset.label = label
      button.dataset.city = city
      button.dataset.province = province
      button.className = "block w-full border-b border-zinc-100 px-4 py-3 text-left text-sm font-semibold text-zinc-700 transition last:border-b-0 hover:bg-brand-50 hover:text-brand-800"
      button.innerHTML = `
        <span class="block font-bold text-zinc-950">${this.escapeHtml(label)}</span>
        <span class="mt-0.5 block text-xs font-semibold text-zinc-500">${this.escapeHtml(this.secondaryLabel(properties))}</span>
      `
      button.addEventListener("click", () => this.selectSuggestion(button))
      this.menuTarget.appendChild(button)
    })

    this.menuTarget.classList.toggle("hidden", this.menuTarget.children.length === 0)
  }

  selectSuggestion(button) {
    this.inputTarget.value = button.dataset.label
    this.latitudeTarget.value = button.dataset.latitude
    this.longitudeTarget.value = button.dataset.longitude
    if (this.hasCityTarget) this.cityTarget.value = button.dataset.city
    if (this.hasProvinceTarget) this.provinceTarget.value = button.dataset.province
    this.showSelectedLocation(button.dataset.label)
    this.hide()
  }

  highlight(items) {
    items.forEach((item, index) => {
      item.classList.toggle("bg-brand-50", index === this.selectedIndex)
      item.classList.toggle("text-brand-800", index === this.selectedIndex)
    })
  }

  hide() {
    this.menuTarget.classList.add("hidden")
    this.selectedIndex = -1
  }

  handleDocumentClick(event) {
    if (!this.element.contains(event.target)) this.hide()
  }

  clearCoordinates() {
    this.latitudeTarget.value = ""
    this.longitudeTarget.value = ""
    if (this.hasCityTarget) this.cityTarget.value = ""
    if (this.hasProvinceTarget) this.provinceTarget.value = ""
    this.marker?.remove()
    this.marker = null
    if (this.hasMapPanelTarget) this.mapPanelTarget.classList.add("hidden")
  }

  showSelectedLocation(label) {
    if (!this.hasMapTarget || !this.hasSelectedCoordinates()) return

    if (this.hasMapPanelTarget) this.mapPanelTarget.classList.remove("hidden")
    this.loadLeaflet()
      .then(() => {
        this.initializeMap()
        this.updateMapMarker(label)
      })
      .catch(() => this.showMapError())
  }

  initializeMap() {
    if (this.map || !window.L) return

    this.map = window.L.map(this.mapTarget, {
      scrollWheelZoom: false
    })

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(this.map)

    window.requestAnimationFrame(() => this.map.invalidateSize())
  }

  updateMapMarker(label) {
    if (!this.map || !window.L) return

    const coordinates = this.selectedCoordinates()
    if (!coordinates) return

    this.marker?.remove()
    this.marker = window.L.marker(coordinates).addTo(this.map)
    if (label) this.marker.bindPopup(this.escapeHtml(label))
    this.map.setView(coordinates, 16)
    window.requestAnimationFrame(() => this.map.invalidateSize())
  }

  selectedCoordinates() {
    const latitude = Number.parseFloat(this.latitudeTarget.value)
    const longitude = Number.parseFloat(this.longitudeTarget.value)
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null

    return [latitude, longitude]
  }

  hasSelectedCoordinates() {
    return Boolean(this.selectedCoordinates())
  }

  loadLeaflet() {
    this.loadLeafletStyles()
    if (window.L) return Promise.resolve()
    if (window.leafletLoadingPromise) return window.leafletLoadingPromise

    window.leafletLoadingPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
      script.async = true
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })

    return window.leafletLoadingPromise
  }

  loadLeafletStyles() {
    if (document.querySelector("link[data-leaflet-css]")) return

    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
    link.dataset.leafletCss = "true"
    document.head.appendChild(link)
  }

  showMapError() {
    if (!this.hasMapTarget) return

    if (this.hasMapPanelTarget) this.mapPanelTarget.classList.remove("hidden")
    this.mapTarget.innerHTML = "<div class='grid h-full place-items-center px-4 text-center text-sm font-bold text-zinc-500'>No se pudo cargar el mapa de OpenStreetMap.</div>"
  }

  formatFeature(properties) {
    return [
      this.streetLine(properties),
      properties.city || properties.town || properties.village || properties.locality,
      properties.state,
      properties.country
    ].filter(Boolean).join(", ")
  }

  streetLine(properties) {
    return [properties.street || properties.name, properties.housenumber].filter(Boolean).join(" ")
  }

  secondaryLabel(properties) {
    return [properties.postcode, this.cityName(properties), properties.state, properties.country].filter(Boolean).join(", ")
  }

  cityName(properties) {
    const directCity = properties.city || properties.town || properties.village || properties.locality || properties.district
    if (directCity) return directCity
    if (this.provinceName(properties) === "CABA") return "Buenos Aires"
    if (properties.type === "city") return properties.name || ""

    return properties.county || ""
  }

  provinceName(properties) {
    const state = properties.state || ""
    if (/ciudad autonoma de buenos aires|ciudad autónoma de buenos aires|capital federal|caba/i.test(state)) {
      return "CABA"
    }

    return state
  }

  escapeHtml(value) {
    return String(value || "").replace(/[&<>"']/g, (character) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;"
    })[character])
  }
}
