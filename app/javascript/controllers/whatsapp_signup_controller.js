import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { appId: String, configId: String, version: String }
  static targets = ["form", "code", "event", "waba", "phone", "status", "button"]

  initialize() { this.attempt = 0; this.receive = this.receive.bind(this) }
  disconnect() {
    window.removeEventListener("message", this.receive)
    this.active = false
    this.attempt++
    clearTimeout(this.completionTimeout)
  }

  async connect() {
    this.ready = false
    window.addEventListener("message", this.receive)
    this.buttonTarget.disabled = true
    this.statusTarget.textContent = "Cargando conexión segura con Meta…"
    try {
      if (!window.FB) {
        window.citapetFacebookSDK ||= new Promise((resolve, reject) => {
          const script = document.createElement("script")
          const timeout = setTimeout(() => reject(new Error("SDK unavailable")), 12000)
          script.src = "https://connect.facebook.net/es_LA/sdk.js"
          script.async = true
          script.crossOrigin = "anonymous"
          script.onload = () => { clearTimeout(timeout); resolve() }
          script.onerror = () => { clearTimeout(timeout); script.remove(); reject(new Error("SDK unavailable")) }
          document.head.appendChild(script)
        })
        await window.citapetFacebookSDK
      }
      if (!this.element.isConnected) return
      if (!window.FB?.init) throw new Error("SDK unavailable")
      window.FB.init({ appId: this.appIdValue, version: this.versionValue, autoLogAppEvents: false, xfbml: false })
      this.ready = true
      this.statusTarget.textContent = ""
    } catch {
      window.citapetFacebookSDK = null
      if (!this.element.isConnected) return
      this.statusTarget.textContent = "No se pudo cargar Meta. Pulsá el botón para reintentar."
    }
    if (this.element.isConnected) this.buttonTarget.disabled = false
  }

  login() {
    if (!this.ready || !window.FB?.login) { this.connect(); return }
    if (this.active || this.submitted) return
    if (window.location.protocol !== "https:") {
      this.statusTarget.textContent = "Abrí Configuración desde la URL pública HTTPS autorizada en Meta para conectar tu cuenta."
      return
    }
    this.active = true
    const attempt = ++this.attempt
    this.submitted = false
    this.codeTarget.value = this.eventTarget.value = this.wabaTarget.value = this.phoneTarget.value = ""
    this.buttonTarget.disabled = true
    this.statusTarget.textContent = "Completá la vinculación oficial de tu WhatsApp Business en Meta."
    try {
      // Keep FB.login synchronous with the click so browsers allow the popup.
      window.FB.login((response) => {
        if (!this.active || this.submitted || this.attempt !== attempt) return
        if (!response.authResponse?.code) {
          this.fail("La autorización se canceló o no fue aprobada. Podés volver a intentarlo.")
          return
        }
        this.codeTarget.value = response.authResponse.code
        // Meta codes expire quickly. Never wait for optional phone IDs.
        this.completionTimeout = setTimeout(() => this.fail("Meta no confirmó Coexistence. Volvé a iniciar la conexión; no continúes con una migración."), 8000)
        this.submitIfReady()
      }, { config_id: this.configIdValue, response_type: "code", override_default_response_type: true,
        extras: { featureType: "whatsapp_business_app_onboarding" } })
    } catch {
      this.fail("Meta no pudo abrir la conexión. Permití ventanas emergentes y reintentá.")
    }
  }

  receive(event) {
    if (!["https://www.facebook.com", "https://web.facebook.com"].includes(event.origin)) return
    if (!this.active || this.submitted) return
    let data
    try { data = typeof event.data === "string" ? JSON.parse(event.data) : event.data } catch { return }
    if (data?.type !== "WA_EMBEDDED_SIGNUP") return
    if (["CANCEL", "ERROR"].includes(data.event)) {
      this.fail("La conexión se canceló o Meta informó un error. Revisá la elegibilidad de Coexistence y volvé a intentarlo.")
      return
    }
    if (data.event?.startsWith("FINISH") && data.event !== "FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING") {
      this.fail("Meta no confirmó WhatsApp Business App Coexistence. La conexión fue detenida: no se admite migración exclusiva a Cloud API.")
      return
    }
    if (data.event !== "FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING") return
    this.eventTarget.value = data.event
    this.wabaTarget.value = data.data?.waba_id || ""
    this.phoneTarget.value = data.data?.phone_number_id || ""
    this.submitIfReady()
  }

  submitIfReady() {
    if (!this.active || this.submitted || !this.codeTarget.value || !this.eventTarget.value) return
    clearTimeout(this.completionTimeout)
    this.submitted = true
    this.active = false
    this.statusTarget.textContent = "Validando tu línea de WhatsApp Business…"
    this.formTarget.requestSubmit()
  }

  fail(message) {
    clearTimeout(this.completionTimeout)
    this.active = false
    this.codeTarget.value = this.eventTarget.value = this.wabaTarget.value = this.phoneTarget.value = ""
    this.buttonTarget.disabled = false
    this.statusTarget.textContent = message
  }
}
