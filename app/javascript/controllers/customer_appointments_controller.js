import { Controller } from "@hotwired/stimulus"
import { bindAppointmentDetailPanel, openProfessionalPicker, renderAppointmentDetail } from "appointment_detail_panel"

export default class extends Controller {
  static targets = ["content", "drawer", "overlay"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  open(event) {
    const url = event.currentTarget.dataset.customerAppointmentsDetailsUrl
    if (url) this.loadDetails(url, event.params.variant || event.currentTarget.dataset.customerAppointmentsVariant || "customer-profile")
  }

  close() {
    this.drawerTarget.classList.remove("is-open")
    this.overlayTarget.classList.remove("is-open")
    this.drawerTarget.setAttribute("aria-hidden", "true")
  }

  async loadDetails(url, variant = "customer-profile") {
    this.detailVariant = variant
    this.contentTarget.innerHTML = '<div class="flex flex-1 items-center justify-center px-8 text-center text-sm font-bold text-slate-500">Cargando detalle del turno…</div>'
    this.drawerTarget.classList.add("is-open")
    this.overlayTarget.classList.add("is-open")
    this.drawerTarget.setAttribute("aria-hidden", "false")

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      const appointment = await response.json().catch(() => null)
      if (!response.ok || !appointment) throw new Error("appointment details unavailable")

      this.appointment = appointment
      this.renderDetails(appointment)
    } catch (_error) {
      this.contentTarget.innerHTML = `
        <div class="flex flex-1 flex-col items-center justify-center gap-3 px-8 text-center">
          <p class="text-lg font-bold text-slate-950">No pudimos cargar el detalle del turno</p>
          <p class="text-sm font-semibold text-slate-500">Probá nuevamente en unos segundos.</p>
        </div>
      `
    }
  }

  renderDetails(appointment) {
    this.contentTarget.innerHTML = renderAppointmentDetail(appointment, {
      actions: {
        changeProfessional: appointment.availableProfessionalsUrl && appointment.changeProfessionalUrl
          ? 'data-action="click->customer-appointments#changeProfessional"'
          : "",
        approveDeposit: appointment.approveDepositUrl
          ? 'data-action="click->customer-appointments#approveDeposit"'
          : "",
        rejectDeposit: appointment.rejectDepositUrl
          ? 'data-action="click->customer-appointments#rejectDeposit"'
          : "",
        markPaid: appointment.markRemainingBalancePaidUrl
          ? 'data-action="click->customer-appointments#markRemainingBalancePaid"'
          : "",
        cancel: appointment.cancelUrl
          ? "data-appointment-detail-cancel"
          : "",
        destroy: appointment.destroyUrl
          ? 'data-action="click->customer-appointments#destroy"'
          : ""
      },
      calendarUrl: appointment.url,
      variant: this.detailVariant || appointment.detailVariant || "customer-profile"
    })
    bindAppointmentDetailPanel(this.contentTarget, {
      onSaveNotes: (internalNotes) => this.saveInternalNotes(internalNotes),
      onCancel: (reason) => this.cancelAppointment(reason)
    })
  }

  async saveInternalNotes(internalNotes) {
    const appointment = await this.patchAppointment(this.appointment?.notesUrl, { appointment: { internal_notes: internalNotes } }, "No pudimos guardar las notas.")
    this.appointment = appointment
    this.renderDetails(appointment)
  }

  async cancelAppointment(reason = "") {
    if (!this.appointment?.cancelUrl) throw new Error("No se pudo cancelar el turno.")

    const response = await this.request(this.appointment.cancelUrl, { reason })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(this.errorMessage(payload, "No se pudo cancelar el turno."))

    this.close()
    this.reloadHistory()
  }

  async approveDeposit() {
    if (!this.appointment?.approveDepositUrl) return
    if (!window.confirm("¿Confirmás que la seña es válida? El turno quedará confirmado.")) return

    await this.updateDepositStatus(this.appointment.approveDepositUrl, {}, "Seña aprobada. El turno fue confirmado.")
  }

  async rejectDeposit() {
    if (!this.appointment?.rejectDepositUrl) return
    const reason = window.prompt("Indicá el motivo para rechazar el comprobante:")?.trim()
    if (!reason) return

    await this.updateDepositStatus(this.appointment.rejectDepositUrl, { reason }, "Comprobante rechazado.")
  }

  async updateDepositStatus(url, body, successMessage) {
    try {
      const appointment = await this.patchAppointment(url, body, "No se pudo actualizar la seña.")
      this.appointment = appointment
      this.renderDetails(appointment)
      this.reloadHistory()
      window.alert(successMessage)
    } catch (error) {
      window.alert(error.message || "No se pudo conectar con el servidor. Probá de nuevo.")
    }
  }

  async markRemainingBalancePaid() {
    if (!this.appointment?.markRemainingBalancePaidUrl) return
    if (!window.confirm(`¿Confirmás que se pagó el total restante de ${this.money(this.appointment.remainingBalance)}?`)) return

    try {
      const appointment = await this.patchAppointment(this.appointment.markRemainingBalancePaidUrl, {}, "No se pudo registrar el pago restante.")
      this.appointment = appointment
      this.renderDetails(appointment)
      this.reloadHistory()
    } catch (error) {
      window.alert(error.message || "No se pudo conectar con el servidor. Probá de nuevo.")
    }
  }

  changeProfessional() {
    if (!this.appointment?.availableProfessionalsUrl || !this.appointment?.changeProfessionalUrl) return

    openProfessionalPicker({
      professionalsUrl: this.appointment.availableProfessionalsUrl,
      selectedProfessionalId: this.appointment.employeeId,
      onConfirm: async (employeeMembershipId) => {
        const appointment = await this.patchAppointment(
          this.appointment.changeProfessionalUrl,
          { employee_membership_id: employeeMembershipId },
          "No se pudo cambiar el profesional."
        )
        this.appointment = appointment
        this.renderDetails(appointment)
        this.reloadHistory()
      }
    })
  }

  async destroy() {
    if (!this.appointment?.destroyUrl) return
    if (!window.confirm("¿Eliminar este turno? Esta acción borra el turno de la agenda. Si necesitás cancelar una reserva, usá Cancelar turno.")) return

    try {
      const response = await fetch(this.appointment.destroyUrl, {
        method: "DELETE",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const payload = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(this.errorMessage(payload, "No se pudo eliminar el turno."))

      this.close()
      this.reloadHistory()
    } catch (error) {
      window.alert(error.message || "No se pudo conectar con el servidor. Probá de nuevo.")
    }
  }

  async patchAppointment(url, body, fallback) {
    if (!url) throw new Error("No tenés permisos para realizar esta acción.")

    const response = await this.request(url, body)
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(this.errorMessage(payload, fallback))

    return payload
  }

  request(url, body = {}) {
    return fetch(url, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: Object.keys(body).length ? JSON.stringify(body) : undefined
    })
  }

  reloadHistory() {
    const frame = document.getElementById("customer_appointment_history")
    if (!frame) return

    const url = new URL(window.location.href)
    url.searchParams.set("section", "appointments")
    url.searchParams.set("page", frame.dataset.customerAppointmentHistoryPage || "1")
    frame.src = url.toString()
    frame.reload?.()
  }

  handleKeydown(event) {
    if (event.key === "Escape" && document.querySelector(".appointment-detail-panel__receipt-dialog[open]")) return
    if (event.key === "Escape" && this.drawerTarget.classList.contains("is-open")) this.close()
  }

  errorMessage(payload, fallback) {
    return Array.isArray(payload?.errors) && payload.errors.length ? payload.errors.join(". ") : fallback
  }

  money(value) {
    return new Intl.NumberFormat("es-AR", {
      style: "currency",
      currency: "ARS",
      maximumFractionDigits: 0
    }).format(Number(value || 0))
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
