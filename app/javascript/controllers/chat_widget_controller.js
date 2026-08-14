import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "messages", "input", "form", "launcher", "contactTemplate"]
  static values = { url: String, businessName: String, servicesDetail: String, initials: String }

  connect() {
    this.opened = false
    this.loading = false
    this.addIntroMessage()
    this.resizeInput()
  }

  toggle() {
    this.opened ? this.close() : this.open()
  }

  open() {
    this.opened = true
    this.panelTarget.classList.remove("hidden")
    this.launcherTarget.classList.add("hidden")
    this.launcherTarget.setAttribute("aria-expanded", "true")
    window.requestAnimationFrame(() => {
      this.inputTarget.focus()
      this.scrollToBottom()
    })
  }

  close() {
    this.opened = false
    this.panelTarget.classList.add("hidden")
    this.launcherTarget.classList.remove("hidden")
    this.launcherTarget.setAttribute("aria-expanded", "false")
  }

  submit(event) {
    event.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message || this.loading) return

    this.sendMessage(message)
  }

  submitOnEnter(event) {
    if (event.shiftKey || event.isComposing) return

    event.preventDefault()
    this.formTarget.requestSubmit()
  }

  resizeInput() {
    if (!this.hasInputTarget) return

    this.inputTarget.style.height = "auto"
    this.inputTarget.style.height = `${this.inputTarget.scrollHeight}px`
  }

  requestHuman() {
    if (this.loading) return

    this.sendMessage("Quiero hablar con una persona")
  }

  quickReply(event) {
    if (this.loading) return

    if (event.currentTarget.dataset.component === "contact") {
      this.addUserMessage("Ubicacion y contacto")
      this.addContactCard()
      return
    }

    const message = event.currentTarget.dataset.message
    if (!message) return

    this.sendMessage(message)
  }

  sendMessage(message) {
    this.addUserMessage(message)
    this.inputTarget.value = ""
    this.resizeInput()
    this.loading = true
    const pending = this.addTypingMessage()

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify({ chat: { message } })
    })
      .then((response) => response.json().then((json) => ({ ok: response.ok, json })))
      .then(({ ok, json }) => {
        pending.remove()
        if (ok && Array.isArray(json.components) && json.components.length > 0) {
          this.addComponentMessage(json.answer, json.components)
        } else {
          this.addMessage(ok ? json.answer : json.error, "assistant")
        }
        if (ok && json.intent === "booking_shortcut") this.triggerBookingShortcut(json)
      })
      .catch(() => {
        pending.remove()
        this.addMessage("No pude responder en este momento.", "assistant")
      })
      .finally(() => {
        this.loading = false
      })
  }

  addIntroMessage() {
    const wrapper = document.createElement("div")
    wrapper.className = "message-enter flex items-start gap-2.5"

    wrapper.appendChild(this.avatarElement())

    const content = document.createElement("div")
    content.className = "max-w-[82%]"

    const bubble = document.createElement("div")
    bubble.className = this.assistantBubbleClasses()
    const text = document.createElement("p")
    text.className = "text-sm font-semibold leading-6 text-zinc-700"
    text.textContent = "Que necesitas hacer hoy?"
    bubble.appendChild(text)
    content.appendChild(bubble)

    const actions = document.createElement("div")
    actions.className = "mt-3 grid gap-2"
    ;[
      {
        label: "Reservar un turno",
        detail: "Elegir servicio, fecha y hora",
        message: "Quiero reservar un turno",
        icon: "calendar",
        featured: true
      },
      {
        label: "Ver servicios y precios",
        detail: this.servicesDetailValue || "Consultar servicios disponibles",
        message: "Ver servicios disponibles",
        icon: "list"
      },
      {
        label: "Consultar disponibilidad",
        detail: "Buscar horarios libres",
        message: "Quiero consultar disponibilidad de horario",
        icon: "clock"
      },
      {
        label: "Ubicación y contacto",
        detail: "Dirección, teléfono y horarios",
        component: "contact",
        icon: "pin"
      }
    ].forEach((action) => actions.appendChild(this.quickActionButton(action)))

    content.appendChild(actions)
    wrapper.appendChild(content)
    this.messagesTarget.appendChild(wrapper)
  }

  quickActionButton(action) {
    const button = document.createElement("button")
    button.type = "button"
    if (action.message) button.dataset.message = action.message
    if (action.component) button.dataset.component = action.component
    button.dataset.action = "chat-widget#quickReply"
    button.className = action.featured
      ? "group flex items-center justify-between gap-3 rounded-2xl border border-brand-100 bg-brand-50 px-3.5 py-3 text-left transition hover:border-brand-300 hover:bg-brand-100"
      : "group flex items-center justify-between gap-3 rounded-2xl border border-zinc-100 bg-white px-3.5 py-3 text-left transition hover:border-brand-200 hover:bg-brand-50"

    const iconClasses = action.featured
      ? "grid h-8 w-8 place-items-center rounded-xl bg-white text-brand-700 shadow-sm"
      : "grid h-8 w-8 place-items-center rounded-xl bg-zinc-50 text-zinc-700"

    button.innerHTML = `
      <span class="flex min-w-0 items-center gap-3">
        <span class="${iconClasses}">${this.icon(action.icon)}</span>
        <span class="min-w-0">
          <span class="block text-xs font-bold text-zinc-900">${action.label}</span>
          <span class="block text-[11px] font-semibold text-zinc-500">${action.detail}</span>
        </span>
      </span>
      <span class="shrink-0 text-zinc-400 transition group-hover:translate-x-0.5 group-hover:text-brand-600">${this.icon("arrow")}</span>
    `
    return button
  }

  addUserMessage(text) {
    return this.addMessage(text, "user")
  }

  addMessage(text, role) {
    const wrapper = document.createElement("div")
    wrapper.className = `${this.messageSpacing()} message-enter ${role === "user" ? "flex justify-end" : "flex items-start gap-2.5"}`

    if (role === "assistant") wrapper.appendChild(this.avatarElement())

    const bubble = document.createElement("div")
    bubble.className = role === "user"
      ? "max-w-[82%] rounded-3xl rounded-tr-md bg-ink px-4 py-3 text-sm font-semibold leading-6 text-white shadow-sm"
      : `${this.assistantBubbleClasses()} max-w-[82%]`
    bubble.textContent = text || "No pude responder en este momento."

    wrapper.appendChild(bubble)
    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
    return wrapper
  }

  addTypingMessage() {
    const wrapper = document.createElement("div")
    wrapper.className = `${this.messageSpacing()} typing-row message-enter flex items-start gap-2.5`
    wrapper.appendChild(this.avatarElement())

    const bubble = document.createElement("div")
    bubble.className = "rounded-3xl rounded-tl-md border border-zinc-100 bg-white px-4 py-3 shadow-sm"
    bubble.innerHTML = `
      <span class="inline-flex items-center gap-1">
        <span class="pulse-dot h-1.5 w-1.5 rounded-full bg-zinc-400"></span>
        <span class="pulse-dot h-1.5 w-1.5 rounded-full bg-zinc-400"></span>
        <span class="pulse-dot h-1.5 w-1.5 rounded-full bg-zinc-400"></span>
      </span>
    `

    wrapper.appendChild(bubble)
    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
    return wrapper
  }

  addComponentMessage(answer, components) {
    const wrapper = document.createElement("div")
    wrapper.className = `${this.messageSpacing()} message-enter flex items-start gap-2.5`
    wrapper.appendChild(this.avatarElement())

    const content = document.createElement("div")
    content.className = "max-w-[92%]"

    const bubble = document.createElement("div")
    bubble.className = `${this.assistantBubbleClasses()} px-4 py-3`

    if (answer) {
      const text = document.createElement("p")
      text.className = "mb-3 text-sm font-semibold leading-6 text-zinc-700"
      text.textContent = answer
      bubble.appendChild(text)
    }

    components.forEach((component) => {
      bubble.appendChild(this.renderComponent(component))
    })

    content.appendChild(bubble)
    wrapper.appendChild(content)
    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
    return wrapper
  }

  renderComponent(component) {
    switch (component.type) {
      case "services_catalog":
        return this.renderServicesCatalog(component)
      case "availability_result":
        return this.renderAvailabilityResult(component)
      case "available_slots":
        return this.renderAvailableSlots(component)
      case "appointments_list":
        return this.renderAppointmentsList(component)
      case "booking_link":
        return this.renderBookingLink(component)
      case "contact_card":
        return this.renderContactCard()
      case "tool_error":
        return this.renderToolError(component)
      default:
        return this.renderToolError({ message: "No pude mostrar este resultado." })
    }
  }

  renderServicesCatalog(component) {
    const container = this.cardContainer()
    ;(component.services || []).forEach((service) => {
      const card = this.card()
      const header = document.createElement("div")
      header.className = "flex items-start justify-between gap-3"

      const copy = document.createElement("div")
      copy.className = "min-w-0"
      const title = document.createElement("p")
      title.className = "text-xs font-bold text-zinc-950"
      title.textContent = service.name
      const meta = document.createElement("p")
      meta.className = "mt-1 text-[11px] font-semibold leading-4 text-zinc-500"
      meta.textContent = `${service.duration_minutes} min · ${service.price_label || "Consultar"}`
      copy.appendChild(title)
      copy.appendChild(meta)
      header.appendChild(copy)

      if (service.deposit_required) {
        const deposit = document.createElement("span")
        deposit.className = "shrink-0 text-right text-[10px] font-bold text-brand-700"
        deposit.textContent = service.deposit_summary
        header.appendChild(deposit)
      }

      card.appendChild(header)
      card.appendChild(this.actionLink("Reservar", service.booking_url, { frame: "booking_flow" }))
      container.appendChild(card)
    })
    return container
  }

  renderAvailabilityResult(component) {
    const card = this.card()
    const status = document.createElement("p")
    status.className = component.available ? "text-xs font-bold text-emerald-700" : "text-xs font-bold text-rose-700"
    status.textContent = component.available ? "Horario disponible" : "Horario no disponible"
    card.appendChild(status)

    const detail = document.createElement("p")
    detail.className = "mt-1 text-[11px] font-semibold leading-4 text-zinc-500"
    detail.textContent = `${component.service?.name || "Servicio"} · ${component.date_label || ""}`
    card.appendChild(detail)

    if (component.available) card.appendChild(this.actionLink("Continuar reserva", component.booking_url, { frame: "booking_flow" }))
    return card
  }

  renderAvailableSlots(component) {
    const slots = component.slots || []
    if (slots.length === 0) {
      return this.renderToolError({ message: "No encontré horarios disponibles para ese servicio y rango." })
    }

    const container = this.cardContainer()

    if (component.searched_range_label || component.period_label) {
      const summary = document.createElement("p")
      summary.className = "px-1 text-[11px] font-bold leading-4 text-zinc-500"
      summary.textContent = [component.searched_range_label, component.period_label].filter(Boolean).join(" · ")
      container.appendChild(summary)
    }

    slots.forEach((slot) => {
      const card = this.card()
      card.classList.add("border-emerald-100", "bg-emerald-50/40")

      const status = document.createElement("p")
      status.className = "text-xs font-bold text-emerald-700"
      status.textContent = "Horario disponible"
      card.appendChild(status)

      const title = document.createElement("p")
      title.className = "mt-1 text-xs font-bold text-zinc-950"
      title.textContent = slot.service_name || component.service?.name || "Servicio"
      card.appendChild(title)

      const meta = document.createElement("p")
      meta.className = "mt-1 text-[11px] font-semibold leading-4 text-zinc-600"
      meta.textContent = slot.starts_at_label || [slot.date_label, slot.time_label].filter(Boolean).join(" ")
      card.appendChild(meta)

      if (slot.employee_membership_name) {
        const professional = document.createElement("p")
        professional.className = "mt-1 text-[11px] font-semibold leading-4 text-zinc-500"
        professional.textContent = slot.employee_membership_name
        card.appendChild(professional)
      }

      card.appendChild(this.actionLink("Reservar", slot.booking_url, { frame: "booking_flow" }))
      container.appendChild(card)
    })

    return container
  }

  renderAppointmentsList(component) {
    const container = this.cardContainer()
    const appointments = component.appointments || []

    if (appointments.length === 0) {
      return this.renderToolError({ message: "No encontré turnos futuros con ese contacto." })
    }

    appointments.forEach((appointment) => {
      const card = this.card()
      const title = document.createElement("p")
      title.className = "text-xs font-bold text-zinc-950"
      title.textContent = appointment.service_name
      card.appendChild(title)

      const meta = document.createElement("p")
      meta.className = "mt-1 text-[11px] font-semibold leading-4 text-zinc-500"
      meta.textContent = appointment.starts_at_label
      card.appendChild(meta)

      card.appendChild(this.actionLink("Confirmar o cancelar", appointment.action_url))
      container.appendChild(card)
    })
    return container
  }

  renderBookingLink(component) {
    const card = this.card()
    const title = document.createElement("p")
    title.className = "text-xs font-bold text-zinc-950"
    title.textContent = component.link_type === "deposit" ? "Seña pendiente" : component.link_type === "confirmed" ? "Turno confirmado" : "Reserva pendiente"
    card.appendChild(title)

    const meta = document.createElement("p")
    meta.className = "mt-1 text-[11px] font-semibold leading-4 text-zinc-500"
    meta.textContent = component.appointment?.starts_at_label || component.service?.name || "Turno"
    card.appendChild(meta)

    card.appendChild(this.actionLink(component.link_type === "deposit" ? "Subir comprobante" : component.link_type === "confirmed" ? "Ver o cancelar turno" : "Abrir WhatsApp", component.url))
    return card
  }

  addContactCard() {
    if (!this.hasContactTemplateTarget) return

    const wrapper = document.createElement("div")
    wrapper.className = `${this.messageSpacing()} message-enter flex items-start gap-2.5`
    wrapper.appendChild(this.avatarElement())

    const content = document.createElement("div")
    content.className = "max-w-[92%]"
    content.appendChild(this.contactTemplateTarget.content.cloneNode(true))

    wrapper.appendChild(content)
    this.messagesTarget.appendChild(wrapper)
    this.scrollToBottom()
    this.initializeMaps(wrapper)
    return wrapper
  }

  renderContactCard() {
    if (!this.hasContactTemplateTarget) return this.renderToolError({ message: "No hay datos de contacto disponibles." })

    const container = document.createElement("div")
    container.appendChild(this.contactTemplateTarget.content.cloneNode(true))
    window.requestAnimationFrame(() => this.initializeMaps(container))
    return container
  }

  renderToolError(component) {
    const card = this.card()
    card.classList.add("border-rose-100", "bg-rose-50")
    const text = document.createElement("p")
    text.className = "text-xs font-bold text-rose-800"
    text.textContent = component.message || "No pude completar esa acción."
    card.appendChild(text)
    return card
  }

  cardContainer() {
    const container = document.createElement("div")
    container.className = "grid gap-2"
    return container
  }

  card() {
    const card = document.createElement("article")
    card.className = "rounded-2xl border border-zinc-100 bg-white px-3 py-3"
    return card
  }

  actionLink(label, url, options = {}) {
    const link = document.createElement("a")
    link.href = url || "#"
    if (options.frame && document.getElementById(options.frame)) {
      link.dataset.turboFrame = options.frame
    } else {
      link.target = "_blank"
      link.rel = "noopener"
    }
    link.className = "mt-3 inline-flex h-9 items-center justify-center rounded-2xl bg-zinc-950 px-3 text-xs font-bold text-white transition hover:bg-zinc-800"
    link.textContent = label
    return link
  }

  initializeMaps(container) {
    const maps = container.querySelectorAll("[data-chat-map]")
    if (maps.length === 0) return

    this.ensureLeaflet()
      .then(() => {
        maps.forEach((element) => this.initializeMap(element))
      })
      .catch(() => {
        maps.forEach((element) => {
          element.innerHTML = "<div class='grid h-full place-items-center px-3 text-center text-xs font-bold text-zinc-500'>No se pudo cargar el mapa.</div>"
        })
      })
  }

  initializeMap(element) {
    if (element.dataset.leafletInitialized === "true" || !window.L) return

    const latitude = Number.parseFloat(element.dataset.latitude)
    const longitude = Number.parseFloat(element.dataset.longitude)
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return

    element.dataset.leafletInitialized = "true"
    const map = window.L.map(element, {
      dragging: false,
      scrollWheelZoom: false,
      doubleClickZoom: false,
      boxZoom: false,
      keyboard: false,
      tap: false,
      zoomControl: false
    }).setView([latitude, longitude], 15)

    window.L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: "&copy; OpenStreetMap"
    }).addTo(map)
    window.L.marker([latitude, longitude]).addTo(map)

    window.requestAnimationFrame(() => map.invalidateSize())
  }

  ensureLeaflet() {
    if (window.L) return Promise.resolve()
    if (this.leafletPromise) return this.leafletPromise

    this.loadLeafletStyles()
    this.leafletPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
      script.async = true
      script.onload = resolve
      script.onerror = reject
      document.head.appendChild(script)
    })

    return this.leafletPromise
  }

  loadLeafletStyles() {
    if (document.querySelector("link[data-leaflet-css]")) return

    const link = document.createElement("link")
    link.rel = "stylesheet"
    link.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
    link.dataset.leafletCss = "true"
    document.head.appendChild(link)
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  messageSpacing() {
    return this.messagesTarget.children.length > 0 ? "mt-4" : ""
  }

  assistantBubbleClasses() {
    return "rounded-3xl rounded-tl-md border border-zinc-100 bg-white px-4 py-3 shadow-sm"
  }

  avatarElement() {
    const avatar = document.createElement("div")
    avatar.className = "grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-ink text-[10px] font-bold text-white"
    avatar.textContent = this.initialsValue || "HT"
    return avatar
  }

  icon(name) {
    const icons = {
      arrow: '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2.2"><path d="m9 18 6-6-6-6"/></svg>',
      calendar: '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7h16M6 3v4M18 3v4M5 5h14a1 1 0 0 1 1 1v14H4V6a1 1 0 0 1 1-1Z"/><path d="m8.5 14 2 2 5-5"/></svg>',
      clock: '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
      list: '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 6h16M4 12h16M4 18h10"/></svg>',
      pin: '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>'
    }
    return icons[name] || icons.arrow
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  triggerBookingShortcut(json) {
    this.close()

    const serviceIds = Array.isArray(json.recommended_service_ids) ? json.recommended_service_ids : []
    const firstService = serviceIds
      .map((id) => document.getElementById(`service-${id}`))
      .find((element) => element)
    const target = firstService || document.getElementById("services-section")

    if (!target) return

    target.scrollIntoView({ behavior: "smooth", block: "center" })
    target.classList.add("ring-4", "ring-brand-200", "ring-offset-2")
    window.setTimeout(() => target.classList.remove("ring-4", "ring-brand-200", "ring-offset-2"), 2400)
  }
}
