import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { appId: String, configId: String, version: String }
  static targets = ["form", "code", "waba", "phone", "status", "button"]

  initialize() { this.receive = this.receive.bind(this) }
  disconnect() { window.removeEventListener("message", this.receive) }

  async connect() {
    window.addEventListener("message", this.receive)
    this.buttonTarget.disabled = true
    if (!window.FB) {
      this.statusTarget.textContent = "Cargando conexión segura con Meta…"
      await new Promise((resolve, reject) => {
        const script = document.createElement("script")
        script.src = "https://connect.facebook.net/es_LA/sdk.js"
        script.onload = resolve
        script.onerror = reject
        document.head.appendChild(script)
      }).catch(() => { this.statusTarget.textContent = "No se pudo cargar Meta. Volvé a intentarlo." })
    }
    if (!window.FB) return
    window.FB.init({ appId: this.appIdValue, version: this.versionValue })
    this.buttonTarget.disabled = false
    this.statusTarget.textContent = ""
  }

  login() {
    if (!window.FB) return
    this.submitted = false
    this.codeTarget.value = this.wabaTarget.value = this.phoneTarget.value = ""
    window.FB.login((response) => {
      if (!response.authResponse?.code) return
      this.codeTarget.value = response.authResponse.code
      this.submitIfReady()
    }, { config_id: this.configIdValue, response_type: "code", override_default_response_type: true,
      extras: { featureType: "whatsapp_business_app_onboarding", sessionInfoVersion: "3", setup: {} } })
  }

  receive(event) {
    if (!["https://www.facebook.com", "https://web.facebook.com"].includes(event.origin)) return
    let data
    try { data = typeof event.data === "string" ? JSON.parse(event.data) : event.data } catch { return }
    if (data?.type !== "WA_EMBEDDED_SIGNUP" || !["FINISH", "FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING"].includes(data.event)) return
    this.wabaTarget.value = data.data?.waba_id || ""
    this.phoneTarget.value = data.data?.phone_number_id || ""
    this.submitIfReady()
  }

  submitIfReady() {
    if (this.submitted || !this.codeTarget.value || !this.wabaTarget.value || !this.phoneTarget.value) return
    this.submitted = true
    this.statusTarget.textContent = "Validando tu línea de WhatsApp Business…"
    this.formTarget.requestSubmit()
  }
}
