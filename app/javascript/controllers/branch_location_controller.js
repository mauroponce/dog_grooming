import { Controller } from "@hotwired/stimulus"

const ARGENTINA_CENTER = [-38.4161, -63.6167]
const ARGENTINA_LOCALITIES_BY_PHOTON_DISTRICT = {
  claypole: "Claypole"
}

export default class extends Controller {
  static targets = [
    "search",
    "suggestions",
    "latitude",
    "longitude",
    "address",
    "city",
    "province",
    "neighborhood",
    "postalCode",
    "country",
    "map",
    "mapContainer",
    "name",
    "phone",
    "previewName",
    "previewAddress",
    "previewPhone",
    "selectedAddress"
  ]

  static values = {
    photonUrl: { type: String, default: "https://photon.komoot.io/api/" }
  }

  connect() {
    this.abortController = null
    this.debounceTimer = null
    this.selectedIndex = -1
    this.features = []
    this.map = null
    this.suggestionLayer = null
    this.selectedMarker = null
    this.suggestionsElement = this.hasSuggestionsTarget ? this.suggestionsTarget : null
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    this.positionSuggestions = this.positionSuggestions.bind(this)
    document.addEventListener("click", this.handleDocumentClick)
    this.mountFloatingSuggestions()
    this.updatePreview()
    if (this.hasCoordinates()) {
      this.showMap().catch(() => this.showMapError())
    } else {
      this.hideMapContainer()
    }
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick)
    window.removeEventListener("resize", this.positionSuggestions)
    window.removeEventListener("scroll", this.positionSuggestions, true)
    window.clearTimeout(this.debounceTimer)
    this.abortController?.abort()
    this.suggestionLayer?.clearLayers()
    this.map?.remove()
    this.map = null
    this.suggestionLayer = null
    this.selectedMarker = null
    this.restoreSuggestions()
  }

  searchChanged() {
    const query = this.searchTarget.value.trim()
    this.clearCoordinates()
    window.clearTimeout(this.debounceTimer)

    if (query.length < 3) {
      this.hideSuggestions()
      this.clearSuggestionMarkers()
      return
    }

    this.debounceTimer = window.setTimeout(() => this.searchPhoton(query), 300)
  }

  keydown(event) {
    const suggestions = this.suggestionsElement
    if (!suggestions) return

    const items = suggestions.querySelectorAll("[data-branch-location-option]")
    if (suggestions.classList.contains("hidden") || items.length === 0) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.hideSuggestions()
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

  searchPhoton(query) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.photonUrlValue)
    url.searchParams.set("q", query)
    url.searchParams.set("limit", "8")
    url.searchParams.set("countrycode", "AR")

    fetch(url.toString(), { signal: this.abortController.signal })
      .then((response) => {
        if (!response.ok) throw new Error("Photon request failed")
        return response.json()
      })
      .then((json) => this.renderResults((json.features || []).filter((feature) => this.isArgentina(feature.properties || {}))))
      .catch((error) => {
        if (error.name !== "AbortError") this.hideSuggestions()
      })
  }

  renderResults(features) {
    this.features = features
    const suggestions = this.suggestionsElement
    if (!suggestions) return

    suggestions.innerHTML = ""
    this.selectedIndex = -1
    this.clearSuggestionMarkers()

    if (features.length === 0) {
      this.hideSuggestions()
      return
    }

    features.forEach((feature, index) => {
      const coordinates = this.coordinatesFor(feature)
      if (!coordinates) return

      const properties = feature.properties || {}
      const label = this.formatAddress(properties)
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.branchLocationOption = "true"
      button.dataset.index = index
      button.className = "block w-full border-b border-zinc-100 px-4 py-3 text-left transition last:border-b-0 hover:bg-zinc-50"
      button.innerHTML = `
        <span class="block text-sm font-bold text-zinc-950">${this.escapeHtml(this.primaryLabel(properties))}</span>
        <span class="mt-1 block text-xs font-semibold text-zinc-500">${this.escapeHtml(label)}</span>
      `
      button.addEventListener("click", () => this.selectFeature(index))
      suggestions.appendChild(button)
    })

    if (suggestions.children.length === 0) {
      this.hideSuggestions()
    } else {
      this.showSuggestions()
    }
    this.renderSuggestionMarkers(features)
  }

  selectFeature(index) {
    const feature = this.features[index]
    const coordinates = this.coordinatesFor(feature)
    if (!coordinates) return

    const properties = feature.properties || {}
    const [latitude, longitude] = coordinates
    const { city, neighborhood } = this.locationFor(properties)
    const province = properties.state || ""
    const address = this.stripTrailingLocationSegments(this.streetLine(properties) || properties.name || "", [neighborhood, city, province, properties.country, "Argentina"])

    this.searchTarget.value = this.formatAddress(properties)
    this.addressTarget.value = address
    this.cityTarget.value = city
    this.provinceTarget.value = province
    this.neighborhoodTarget.value = neighborhood
    if (this.hasPostalCodeTarget) this.postalCodeTarget.value = properties.postcode || ""
    this.countryTarget.value = "Argentina"
    this.latitudeTarget.value = latitude
    this.longitudeTarget.value = longitude

    this.hideSuggestions()
    this.showMap().then(() => {
      this.setSelectedMarker(latitude, longitude, this.formatAddress(properties))
      this.updatePreview()
    })
  }

  updatePreview() {
    if (this.hasPreviewNameTarget) this.previewNameTarget.textContent = this.nameTarget.value.trim() || "Sucursal"
    if (this.hasPreviewAddressTarget) this.previewAddressTarget.textContent = this.visibleAddress() || "Dirección a confirmar"
    if (this.hasPreviewPhoneTarget) this.previewPhoneTarget.textContent = `WhatsApp: ${this.phoneTarget.value.trim() || "usa WhatsApp general"}`
    if (this.hasSelectedAddressTarget) this.selectedAddressTarget.textContent = this.visibleAddress() || "Elegí una dirección para guardar el punto exacto."
  }

  recenter() {
    if (!this.map) return

    const latitude = Number.parseFloat(this.latitudeTarget.value)
    const longitude = Number.parseFloat(this.longitudeTarget.value)
    if (Number.isFinite(latitude) && Number.isFinite(longitude)) {
      this.map.setView([latitude, longitude], 16)
      return
    }

    this.map.setView(ARGENTINA_CENTER, 4)
  }

  useCurrentLocation() {
    if (!navigator.geolocation) return

    navigator.geolocation.getCurrentPosition((position) => {
      const latitude = position.coords.latitude
      const longitude = position.coords.longitude
      if (!this.inArgentina(latitude, longitude)) return

      this.latitudeTarget.value = latitude.toFixed(7)
      this.longitudeTarget.value = longitude.toFixed(7)
      this.setSelectedMarker(latitude, longitude, this.visibleAddress() || "Ubicación actual")
    })
  }

  initializeMap() {
    if (!window.L || !this.hasMapTarget || this.map) return

    const latitude = Number.parseFloat(this.latitudeTarget.value)
    const longitude = Number.parseFloat(this.longitudeTarget.value)
    const hasPoint = Number.isFinite(latitude) && Number.isFinite(longitude)
    const center = hasPoint ? [latitude, longitude] : ARGENTINA_CENTER
    const zoom = hasPoint ? 15 : 4

    this.map = window.L.map(this.mapTarget, {
      scrollWheelZoom: false
    }).setView(center, zoom)

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(this.map)

    this.suggestionLayer = window.L.layerGroup().addTo(this.map)
    if (hasPoint) this.setSelectedMarker(latitude, longitude, this.visibleAddress())
    this.refreshMap()
  }

  renderSuggestionMarkers(features) {
    if (!this.map || !window.L) return

    const bounds = []
    features.forEach((feature, index) => {
      const coordinates = this.coordinatesFor(feature)
      if (!coordinates) return

      bounds.push(coordinates)
      const marker = window.L.circleMarker(coordinates, {
        radius: 8,
        color: "#FFDED4",
        fillColor: "#FFDED4",
        fillOpacity: 0.35,
        weight: 2
      }).addTo(this.suggestionLayer)
      marker.on("click", () => this.selectFeature(index))
    })

    if (bounds.length > 0) this.map.fitBounds(bounds, { padding: [32, 32], maxZoom: 15 })
  }

  clearSuggestionMarkers() {
    this.suggestionLayer?.clearLayers()
  }

  clearCoordinates() {
    this.latitudeTarget.value = ""
    this.longitudeTarget.value = ""
    this.addressTarget.value = ""
    this.cityTarget.value = ""
    this.provinceTarget.value = ""
    if (this.hasNeighborhoodTarget) this.neighborhoodTarget.value = ""
    if (this.hasPostalCodeTarget) this.postalCodeTarget.value = ""
    this.hideMapContainer()
    this.selectedMarker?.remove()
    this.selectedMarker = null
  }

  waitForMapVisible() {
    return new Promise((resolve) => {
      let attempts = 0
      const check = () => {
        attempts += 1
        if (!this.hasMapTarget || !this.hasMapContainerTarget) {
          resolve()
          return
        }

        const rect = this.mapTarget.getBoundingClientRect()
        if ((rect.width > 0 && rect.height > 0) || attempts > 30) {
          resolve()
          return
        }

        window.requestAnimationFrame(check)
      }

      window.requestAnimationFrame(check)
    })
  }

  setSelectedMarker(latitude, longitude, label) {
    if (!this.map || !window.L) return

    const coordinates = [Number(latitude), Number(longitude)]
    this.selectedMarker?.remove()
    this.selectedMarker = window.L.marker(coordinates).addTo(this.map)
    if (label) this.selectedMarker.bindPopup(label)
    this.map.setView(coordinates, 16)
    this.clearSuggestionMarkers()
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

    this.mapTarget.innerHTML = "<div class='grid h-full place-items-center px-4 text-center text-sm font-bold text-zinc-500'>No se pudo cargar el mapa de OpenStreetMap.</div>"
    this.showMapContainer()
  }

  hideSuggestions() {
    this.suggestionsElement?.classList.add("hidden")
    this.selectedIndex = -1
  }

  handleDocumentClick(event) {
    if (!this.element.contains(event.target) && !this.suggestionsElement?.contains(event.target)) this.hideSuggestions()
  }

  mountFloatingSuggestions() {
    if (!this.suggestionsElement) return

    this.suggestionsOriginalParent = this.suggestionsElement.parentElement
    this.suggestionsOriginalNextSibling = this.suggestionsElement.nextSibling
    this.suggestionsElement.dataset.branchLocationFloating = "true"
    document.body.appendChild(this.suggestionsElement)
    window.addEventListener("resize", this.positionSuggestions)
    window.addEventListener("scroll", this.positionSuggestions, true)
  }

  restoreSuggestions() {
    if (!this.suggestionsElement || !this.suggestionsOriginalParent) return

    this.hideSuggestions()
    delete this.suggestionsElement.dataset.branchLocationFloating
    this.suggestionsElement.removeAttribute("style")
    if (this.suggestionsOriginalNextSibling?.parentNode === this.suggestionsOriginalParent) {
      this.suggestionsOriginalParent.insertBefore(this.suggestionsElement, this.suggestionsOriginalNextSibling)
    } else {
      this.suggestionsOriginalParent.appendChild(this.suggestionsElement)
    }
  }

  showSuggestions() {
    this.suggestionsElement?.classList.remove("hidden")
    this.positionSuggestions()
  }

  positionSuggestions() {
    if (!this.hasSearchTarget || !this.suggestionsElement) return
    if (this.suggestionsElement.classList.contains("hidden")) return

    const rect = this.searchTarget.getBoundingClientRect()
    const spacing = 8
    const viewportPadding = 12
    const availableBelow = window.innerHeight - rect.bottom - spacing - viewportPadding
    const availableAbove = rect.top - spacing - viewportPadding
    const openAbove = availableBelow < 180 && availableAbove > availableBelow
    const availableSpace = openAbove ? availableAbove : availableBelow
    const maxHeight = Math.max(160, Math.min(360, availableSpace))
    const left = Math.min(
      Math.max(rect.left, viewportPadding),
      Math.max(viewportPadding, window.innerWidth - rect.width - viewportPadding)
    )

    Object.assign(this.suggestionsElement.style, {
      bottom: openAbove ? `${window.innerHeight - rect.top + spacing}px` : "auto",
      left: `${left}px`,
      maxHeight: `${maxHeight}px`,
      overflowY: "auto",
      position: "fixed",
      right: "auto",
      top: openAbove ? "auto" : `${rect.bottom + spacing}px`,
      width: `${rect.width}px`,
      zIndex: "2147483000"
    })
  }

  highlight(items) {
    items.forEach((item, index) => {
      item.classList.toggle("bg-zinc-50", index === this.selectedIndex)
    })
  }

  coordinatesFor(feature) {
    const coordinates = feature?.geometry?.coordinates || []
    const longitude = Number.parseFloat(coordinates[0])
    const latitude = Number.parseFloat(coordinates[1])
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null
    if (!this.inArgentina(latitude, longitude)) return null

    return [latitude, longitude]
  }

  inArgentina(latitude, longitude) {
    return latitude >= -55.2 && latitude <= -21.7 && longitude >= -73.7 && longitude <= -53.6
  }

  isArgentina(properties) {
    return String(properties.countrycode || "").toLowerCase() === "ar" || String(properties.country || "").toLowerCase() === "argentina"
  }

  visibleAddress() {
    return this.deduplicatedAddressParts([this.addressTarget.value, this.neighborhoodTarget.value, this.cityTarget.value, this.provinceTarget.value]).join(", ")
  }

  hasCoordinates() {
    const latitude = Number.parseFloat(this.latitudeTarget.value)
    const longitude = Number.parseFloat(this.longitudeTarget.value)
    return Number.isFinite(latitude) && Number.isFinite(longitude)
  }

  hideMapContainer() {
    if (this.hasMapContainerTarget) this.mapContainerTarget.classList.add("hidden")
  }

  showMapContainer() {
    if (this.hasMapContainerTarget) this.mapContainerTarget.classList.remove("hidden")
  }

  refreshMap(callback) {
    if (!this.map) {
      if (callback) callback()
      return Promise.resolve()
    }

    return new Promise((resolve) => {
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          this.map?.invalidateSize()
          if (callback) callback()
          resolve()
        })
      })
    })
  }

  showMap() {
    if (!this.hasMapTarget) return Promise.resolve()

    this.showMapContainer()
    return new Promise((resolve) => {
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(resolve)
      })
    })
      .then(() => this.waitForMapVisible())
      .then(() => this.loadLeaflet())
      .then(() => {
        this.initializeMap()
        return this.refreshMap()
      })
  }

  primaryLabel(properties) {
    return this.streetLine(properties) || properties.name || "Ubicación encontrada"
  }

  formatAddress(properties) {
    const { city, neighborhood } = this.locationFor(properties)
    const province = properties.state
    const address = this.stripTrailingLocationSegments(this.streetLine(properties) || properties.name, [neighborhood, city, province, properties.country, "Argentina"])

    return this.deduplicatedAddressParts([
      address,
      neighborhood,
      city,
      province,
      "Argentina"
    ]).join(", ")
  }

  locationFor(properties) {
    const district = properties.district || properties.suburb || properties.locality || ""
    const districtLocality = this.argentineLocalityFor(district, properties)

    if (districtLocality) {
      return { city: districtLocality, neighborhood: "" }
    }

    return {
      city: properties.city || properties.town || properties.village || properties.locality || properties.county || "",
      neighborhood: district
    }
  }

  argentineLocalityFor(district, properties) {
    if (!this.isArgentina(properties)) return ""

    return ARGENTINA_LOCALITIES_BY_PHOTON_DISTRICT[this.locationPartKey(district)] || ""
  }

  streetLine(properties) {
    return [properties.street || properties.name, properties.housenumber].filter(Boolean).join(" ")
  }

  stripTrailingLocationSegments(value, suffixes) {
    const suffixKeys = suffixes.map((suffix) => this.locationPartKey(suffix)).filter(Boolean)
    const segments = String(value || "").split(",").map((part) => part.trim()).filter(Boolean)

    while (segments.length > 1 && suffixKeys.includes(this.locationPartKey(segments[segments.length - 1]))) {
      segments.pop()
    }

    return segments.join(", ")
  }

  deduplicatedAddressParts(parts) {
    const seenKeys = []
    const cleaned = []

    parts.forEach((part) => {
      const value = String(part || "").trim()
      const key = this.locationPartKey(value)
      if (!value || !key || seenKeys.includes(key)) return

      cleaned.push(value)
      value.split(",").forEach((segment) => {
        const segmentKey = this.locationPartKey(segment)
        if (segmentKey) seenKeys.push(segmentKey)
      })
    })

    return cleaned
  }

  locationPartKey(value) {
    return String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().replace(/\s+/g, " ").toLowerCase()
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
