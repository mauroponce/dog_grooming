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
    const url = event.currentTarget.dataset.homeAppointmentsDetailsUrl
    if (!url) return

    this.loadDetails(url)
  }

  openFromKeyboard(event) {
    if (!["Enter", " "].includes(event.key)) return

    event.preventDefault()
    this.open(event)
  }

  close() {
    this.drawerTarget.classList.remove("open")
    this.overlayTarget.classList.remove("open")
    this.drawerTarget.setAttribute("aria-hidden", "true")
  }

  async destroy() {
    if (!this.appointment?.destroyUrl) return
    if (!window.confirm("¿Eliminar este turno? Esta acción borra el turno de la agenda. Si necesitás cancelar una reserva, usá Cancelar turno.")) return

    try {
      const response = await fetch(this.appointment.destroyUrl, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })
      const payload = await response.json().catch(() => ({}))

      if (!response.ok) {
        window.alert(Array.isArray(payload.errors) && payload.errors.length ? payload.errors.join(". ") : "No se pudo eliminar el turno.")
        return
      }

      this.close()
      this.reloadUpcomingAppointments()
    } catch (_error) {
      window.alert("No se pudo conectar con el servidor. Probá de nuevo.")
    }
  }

  async markRemainingBalancePaid() {
    if (!this.appointment?.markRemainingBalancePaidUrl) return

    const amount = this.money(this.appointment.remainingBalance)
    if (!window.confirm(`¿Confirmás que se pagó el total restante de ${amount}?`)) return

    const button = this.contentTarget.querySelector("[data-home-appointments-mark-paid]")
    if (button) {
      button.disabled = true
      button.textContent = "Guardando..."
    }

    try {
      const response = await fetch(this.appointment.markRemainingBalancePaidUrl, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        }
      })
      const appointment = await response.json().catch(() => null)

      if (!response.ok || !appointment) {
        const message = Array.isArray(appointment?.errors) && appointment.errors.length
          ? appointment.errors.join(". ")
          : "No se pudo registrar el pago restante."
        window.alert(message)
        return
      }

      this.appointment = appointment
      this.renderDetails(appointment)
    } catch (_error) {
      window.alert("No se pudo conectar con el servidor. Probá de nuevo.")
    } finally {
      if (button?.isConnected) {
        button.disabled = false
        button.textContent = "Marcar como pagado"
      }
    }
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
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        body: JSON.stringify(body)
      })
      const appointment = await response.json().catch(() => null)

      if (!response.ok || !appointment) {
        const message = Array.isArray(appointment?.errors) && appointment.errors.length
          ? appointment.errors.join(". ")
          : "No se pudo actualizar la seña."
        window.alert(message)
        return
      }

      this.appointment = appointment
      this.renderDetails(appointment)
      this.reloadUpcomingAppointments()
      window.alert(successMessage)
    } catch (_error) {
      window.alert("No se pudo conectar con el servidor. Probá de nuevo.")
    }
  }

  changeProfessional() {
    if (!this.appointment?.availableProfessionalsUrl || !this.appointment?.changeProfessionalUrl) return

    openProfessionalPicker({
      professionalsUrl: this.appointment.availableProfessionalsUrl,
      selectedProfessionalId: this.appointment.employeeId,
      onConfirm: async (employeeMembershipId) => {
        const response = await fetch(this.appointment.changeProfessionalUrl, {
          method: "PATCH",
          headers: {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
          },
          body: JSON.stringify({ employee_membership_id: employeeMembershipId })
        })
        const appointment = await response.json().catch(() => ({}))
        if (!response.ok) {
          throw new Error(Array.isArray(appointment.errors) ? appointment.errors.join(". ") : "No se pudo cambiar el profesional.")
        }

        this.appointment = appointment
        this.renderDetails(appointment)
        this.reloadUpcomingAppointments()
      }
    })
  }

  async loadDetails(url) {
    this.contentTarget.innerHTML = '<div class="flex flex-1 items-center justify-center text-sm font-bold text-slate-500">Cargando detalle del turno…</div>'
    this.drawerTarget.classList.add("open")
    this.overlayTarget.classList.add("open")
    this.drawerTarget.setAttribute("aria-hidden", "false")

    try {
      const response = await fetch(url, { headers: { "Accept": "application/json" } })
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
          ? 'data-action="click->home-appointments#changeProfessional"'
          : "",
        approveDeposit: appointment.approveDepositUrl ? 'data-action="click->home-appointments#approveDeposit"' : "",
        rejectDeposit: appointment.rejectDepositUrl ? 'data-action="click->home-appointments#rejectDeposit"' : "",
        markPaid: appointment.markRemainingBalancePaidUrl
          ? 'data-home-appointments-mark-paid data-action="click->home-appointments#markRemainingBalancePaid"'
          : "",
        cancel: appointment.cancelUrl ? "data-appointment-detail-cancel" : "",
        destroy: appointment.destroyUrl ? 'data-action="click->home-appointments#destroy"' : ""
      },
      calendarUrl: appointment.url
    })
    bindAppointmentDetailPanel(this.contentTarget, {
      onSaveNotes: (internalNotes) => this.saveInternalNotes(internalNotes),
      onCancel: (reason) => this.cancelAppointment(reason)
    })
  }

  async cancelAppointment(reason = "") {
    if (!this.appointment?.cancelUrl) throw new Error("No se pudo cancelar el turno.")

    const response = await fetch(this.appointment.cancelUrl, {
      method: "PATCH",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      body: JSON.stringify({ reason })
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(Array.isArray(payload.errors) && payload.errors.length ? payload.errors.join(". ") : "No se pudo cancelar el turno.")
    }

    this.close()
    this.reloadUpcomingAppointments()
  }

  async saveInternalNotes(internalNotes) {
    if (!this.appointment?.notesUrl) throw new Error("No tenés permisos para editar las notas del turno.")

    const response = await fetch(this.appointment.notesUrl, {
      method: "PATCH",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
      },
      body: JSON.stringify({ appointment: { internal_notes: internalNotes } })
    })
    const appointment = await response.json().catch(() => ({}))
    if (!response.ok) {
      throw new Error(Array.isArray(appointment.errors) ? appointment.errors.join(". ") : "No pudimos guardar las notas.")
    }

    this.appointment = appointment
    this.renderDetails(appointment)
  }

  reloadUpcomingAppointments() {
    const frame = document.getElementById("home_upcoming_appointments")
    if (!frame) return

    const url = new URL(window.location.href)
    const page = frame.dataset.homeUpcomingCurrentPage || "1"
    if (page === "1") {
      url.searchParams.delete("upcoming_page")
    } else {
      url.searchParams.set("upcoming_page", page)
    }
    frame.src = url.toString()
    frame.reload?.()
  }

  handleKeydown(event) {
    if (event.key === "Escape" && document.querySelector(".appointment-detail-panel__receipt-dialog[open]")) return
    if (event.key === "Escape" && this.drawerTarget.classList.contains("open")) this.close()
  }

  money(value) {
    return new Intl.NumberFormat("es-AR", {
      style: "currency",
      currency: "ARS",
      maximumFractionDigits: 0
    }).format(Number(value || 0))
  }

}
