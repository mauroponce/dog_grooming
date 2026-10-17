const escapeHTML = (value) => String(value ?? "").replace(/[&<>"']/g, (character) => ({
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;"
}[character]))

const escapeAttribute = (value) => escapeHTML(value).replace(/`/g, "&#96;")

const money = (value) => new Intl.NumberFormat("es-AR", {
  style: "currency",
  currency: "ARS",
  maximumFractionDigits: 0
}).format(Number(value || 0))

const dateTime = (value) => {
  const date = new Date(value)
  if (!value || Number.isNaN(date.getTime())) return "Sin registrar"

  const parts = new Intl.DateTimeFormat("es-AR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).formatToParts(date).reduce((result, part) => {
    result[part.type] = part.value
    return result
  }, {})

  return `${parts.day}/${parts.month}/${parts.year}, ${parts.hour}:${parts.minute}hs`
}

const durationLabel = (value) => {
  const minutes = Number(value || 0)
  if (minutes < 60) return `${minutes} min`

  const hours = Math.floor(minutes / 60)
  const remainder = minutes % 60
  return remainder ? `${hours} h ${remainder} min` : `${hours} h`
}

const initials = (value) => String(value || "C")
  .trim()
  .split(/\s+/)
  .filter(Boolean)
  .slice(0, 2)
  .map((part) => part[0])
  .join("")
  .toUpperCase() || "C"

const statusTone = (appointment) => {
  const status = String(appointment.status || "")
  if (status === "completed") return "violet"
  if (["confirmed", "pending_confirmation"].includes(status)) return "emerald"
  if (["pending_deposit_review"].includes(status)) return "amber"
  if (["pending_deposit", "deposit_rejected", "pending_payment", "canceled", "no_show"].includes(status)) return "rose"
  return "zinc"
}

const detailRow = (label, value) => `
  <div class="appointment-detail-panel__row">
    <span>${escapeHTML(label)}</span>
    <strong>${escapeHTML(value || "Sin registrar")}</strong>
  </div>
`

const professionalRow = (appointment, changeProfessionalAttributes) => `
  <div class="appointment-detail-panel__row appointment-detail-panel__professional-row">
    <span>Profesional</span>
    <div>
      <strong>${escapeHTML(appointment.employeeName || "Agenda del centro")}</strong>
      ${changeProfessionalAttributes ? `<button type="button" ${changeProfessionalAttributes}>Cambiar profesional</button>` : ""}
    </div>
  </div>
`

const actionButton = (label, tone, attributes) => attributes
  ? `<button type="button" class="appointment-detail-panel__action is-${tone}" ${attributes}>${escapeHTML(label)}</button>`
  : ""

const customerDetailLinks = (appointment) => `
  <div class="appointment-detail-panel__customer-links">
    ${appointment.customerProfileUrl
      ? `<a href="${escapeAttribute(appointment.customerProfileUrl)}">Ver Detalle</a>`
      : '<span class="is-disabled">Sin detalle de cliente</span>'}
  </div>
`

const internalNotesSection = (appointment) => {
  const notes = String(appointment.internalNotes || "")
  const hasNotes = notes.trim().length > 0
  const editable = Boolean(appointment.notesUrl)
  const formHidden = hasNotes ? "" : " hidden"
  const addButton = editable && !hasNotes
    ? '<button type="button" class="appointment-detail-panel__notes-link" data-appointment-detail-notes-edit>Añadir notas</button>'
    : ""

  return `
    <section class="appointment-detail-panel__section appointment-detail-panel__notes-section">
      <div class="appointment-detail-panel__section-heading">
        <h3>Notas del turno</h3>
        ${addButton}
      </div>
      ${editable ? `
        <div class="appointment-detail-panel__notes-form" data-appointment-detail-notes-form data-has-notes="${hasNotes}" data-initial-notes="${escapeAttribute(notes)}"${formHidden}>
          <textarea rows="5" maxlength="5000" aria-label="Notas internas del turno" data-appointment-detail-notes-input>${escapeHTML(notes)}</textarea>
          <p class="appointment-detail-panel__notes-error hidden" data-appointment-detail-notes-error></p>
          <div>
            <button type="button" data-appointment-detail-notes-save hidden>Guardar</button>
            <button type="button" data-appointment-detail-notes-cancel>Cancelar</button>
          </div>
        </div>
      ` : (hasNotes ? `<p class="appointment-detail-panel__note">${escapeHTML(notes)}</p>` : '<p class="appointment-detail-panel__note is-empty">Sin notas internas.</p>')}
    </section>
  `
}

const customerCommentSection = (appointment) => {
  const comment = String(appointment.customerComment || "").trim()
  if (!comment) return ""

  return `
    <section class="appointment-detail-panel__section appointment-detail-panel__customer-comment">
      <h3>Comentarios del cliente</h3>
      <p class="appointment-detail-panel__note">${escapeHTML(comment)}</p>
    </section>
  `
}

const serviceVariantSection = (appointment) => {
  const options = Array.isArray(appointment.serviceVariantOptions) ? appointment.serviceVariantOptions : []
  if (!appointment.updateServiceVariantUrl || !options.length) return ""

  return `
    <section class="appointment-detail-panel__section">
      <h3>Tamaño de la mascota</h3>
      <div class="appointment-detail-panel__row">
        <span>Rango confirmado</span>
        <select data-appointment-detail-service-variant aria-label="Tamaño de la mascota">
          ${options.map((option) => `<option value="${escapeAttribute(option.id)}" ${String(option.id) === String(appointment.serviceVariantId || "") ? "selected" : ""}>${escapeHTML(option.label)} · ${money(option.price)} · ${durationLabel(option.duration)}</option>`).join("")}
        </select>
      </div>
      <p class="appointment-detail-panel__notes-error hidden" data-appointment-detail-service-variant-error></p>
    </section>
  `
}

export function renderAppointmentDetail(appointment, { actions = {}, variant = "default" } = {}) {
  const services = appointment.services?.length
    ? appointment.services
    : [{ name: appointment.service, duration: appointment.duration, price: appointment.price }]
  const resolvedVariant = appointment.detailVariant || variant
  const customerProfileVariant = resolvedVariant === "customer-profile"
  const depositAmount = Number(appointment.depositAmount || 0)
  const remainingPaidAt = appointment.remainingBalancePaidAt
  const remainingPaidAmount = Number(appointment.remainingBalancePaidAmount || 0)
  const remainingBalance = Number(appointment.remainingBalance ?? appointment.price ?? 0)
  const customerSummary = appointment.customerSummary || {}
  const paymentStatus = appointment.depositStatusLabel || (depositAmount > 0 ? "Seña pendiente" : "Sin seña")
  const paymentMethod = appointment.depositPaymentMethod || "Medio no registrado"
  const remainingMethod = appointment.remainingBalancePaymentMethod || paymentMethod
  const location = [appointment.branchName, appointment.resourceName].filter(Boolean).join(" · ")
  const actionMarkup = [
    actionButton("Aprobar seña", "approve", actions.approveDeposit),
    actionButton("Rechazar seña", "secondary-danger", actions.rejectDeposit),
    actionButton("Marcar como pagado", "primary", actions.markPaid),
    actionButton("Cancelar turno", "danger", actions.cancel),
    actionButton("Eliminar turno", "secondary-danger", actions.destroy)
  ].filter(Boolean).join("")

  return `
    <div class="appointment-detail-panel${customerProfileVariant ? " is-customer-profile" : ""}">
      <aside class="appointment-detail-panel__customer">
        <div class="appointment-detail-panel__avatar">${escapeHTML(initials(appointment.client))}</div>
        <h2>${escapeHTML(appointment.client || "Cliente")}</h2>
        <p class="appointment-detail-panel__customer-status is-${escapeAttribute(customerSummary.statusTone || "zinc")}">${escapeHTML(customerSummary.statusLabel || "Cliente")}</p>

        <dl class="appointment-detail-panel__customer-data">
          ${appointment.petName ? `<div><dt>Mascota</dt><dd>${escapeHTML(appointment.petName)}</dd></div>` : ""}
          <div><dt>Responsable</dt><dd>${escapeHTML(appointment.ownerName || appointment.client || "Sin registrar")}</dd></div>
          <div><dt>Teléfono</dt><dd>${escapeHTML(appointment.phone || "Sin teléfono")}</dd></div>
          <div><dt>Email</dt><dd>${appointment.customerEmail ? `<a href="mailto:${escapeAttribute(appointment.customerEmail)}">${escapeHTML(appointment.customerEmail)}</a>` : "Sin email"}</dd></div>
          <div><dt>Cliente desde</dt><dd>${escapeHTML(appointment.customerCreatedAt ? dateTime(appointment.customerCreatedAt).split(",")[0] : "Sin registrar")}</dd></div>
        </dl>

        <div class="appointment-detail-panel__customer-metrics">
          <span>${Number(customerSummary.appointmentsCount || 0)} turnos</span>
          <span>${money(customerSummary.totalSales)} facturado</span>
          ${Number(customerSummary.noShowCount || 0) > 0 ? `<span>${Number(customerSummary.noShowCount)} ausencias</span>` : ""}
        </div>

        ${customerDetailLinks(appointment)}
      </aside>

      <section class="appointment-detail-panel__main">
        <header class="appointment-detail-panel__header">
          <div>
            <p>DETALLE DEL TURNO</p>
            <h1>${escapeHTML(customerProfileVariant ? appointment.service || "Turno" : appointment.statusLabel || appointment.status || "Turno")}</h1>
          </div>
          <span class="appointment-detail-panel__status is-${statusTone(appointment)}">${escapeHTML(appointment.statusLabel || appointment.status || "Sin estado")}</span>
        </header>

        <div class="appointment-detail-panel__body">
          <section class="appointment-detail-panel__section">
            <h3>Agenda</h3>
            <div class="appointment-detail-panel__rows">
              ${detailRow("Fecha y hora", `${dateTime(appointment.startsAt)} · ${durationLabel(appointment.duration)}`)}
              ${professionalRow(appointment, actions.changeProfessional)}
              ${customerProfileVariant ? "" : `
                ${detailRow("Finaliza", dateTime(appointment.endsAt))}
                ${location ? detailRow("Ubicación", location) : ""}
                ${detailRow("Origen", appointment.sourceLabel || "Sin registrar")}
                ${detailRow("Reserva creada", dateTime(appointment.createdAt))}
                ${appointment.confirmedAt ? detailRow("Confirmado", dateTime(appointment.confirmedAt)) : ""}
              `}
            </div>
          </section>

          ${appointment.petName ? `<section class="appointment-detail-panel__section">
            <h3>Mascota</h3>
            <div class="appointment-detail-panel__rows">
              ${detailRow("Nombre", appointment.petName)}
              ${appointment.petBreed ? detailRow("Raza", appointment.petBreed) : ""}
              ${appointment.petSex ? detailRow("Sexo", appointment.petSex) : ""}
              ${appointment.petNotes ? detailRow("Cuidados", appointment.petNotes) : ""}
            </div>
          </section>` : ""}

          ${customerProfileVariant ? "" : `<section class="appointment-detail-panel__section">
            <h3>Servicios</h3>
            <div class="appointment-detail-panel__services">
              ${services.map((service) => `
                <div>
                  <span><strong>${escapeHTML(service.name)}</strong><small>${escapeHTML(durationLabel(service.duration))}</small></span>
                  <b>${money(service.price)}</b>
                </div>
              `).join("")}
              <div class="appointment-detail-panel__total"><span>Total</span><b>${money(appointment.totalPrice ?? appointment.price)}</b></div>
            </div>
          </section>`}

          ${serviceVariantSection(appointment)}

          <section class="appointment-detail-panel__section">
            <h3>Pagos</h3>
            <div class="appointment-detail-panel__rows">
              ${depositAmount > 0 ? detailRow("Seña", `${money(depositAmount)} · ${customerProfileVariant && appointment.depositPaidAt ? dateTime(appointment.depositPaidAt) : paymentStatus}`) : detailRow("Seña", "No requiere seña")}
              ${depositAmount > 0 ? detailRow("Medio de seña", paymentMethod) : ""}
              ${depositAmount > 0 && !customerProfileVariant ? detailRow("Seña registrada", dateTime(appointment.depositPaidAt)) : ""}
              ${appointment.depositRejectionReason ? detailRow("Observación del comprobante", appointment.depositRejectionReason) : ""}
              ${appointment.depositReceiptPreviewUrl ? `
                <div class="appointment-detail-panel__receipt">
                  <span>Comprobante</span>
                  <button type="button" data-appointment-detail-receipt-preview aria-label="Ver comprobante en pantalla completa">
                    <img src="${escapeAttribute(appointment.depositReceiptPreviewUrl)}" alt="Comprobante subido por ${escapeAttribute(appointment.client || "el cliente")}">
                    <b>Ver en pantalla completa</b>
                  </button>
                </div>
              ` : appointment.depositReceiptUrl ? `<div class="appointment-detail-panel__row"><span>Comprobante</span><a href="${escapeAttribute(appointment.depositReceiptUrl)}">Ver comprobante</a></div>` : ""}
              ${remainingPaidAt
                ? detailRow("Restante pagado", `${money(remainingPaidAmount)} · ${dateTime(remainingPaidAt)}`)
                : detailRow("Resta pagar", money(remainingBalance))}
              ${remainingPaidAt ? detailRow("Medio del restante", remainingMethod) : ""}
            </div>
          </section>

          ${internalNotesSection(appointment)}
          ${customerCommentSection(appointment)}

          ${appointment.canceledAt || appointment.cancellationReason ? `
            <section class="appointment-detail-panel__section is-alert">
              <h3>Cancelación</h3>
              <div class="appointment-detail-panel__rows">
                ${detailRow("Cancelado", dateTime(appointment.canceledAt))}
                ${detailRow("Por", appointment.canceledByLabel)}
                ${appointment.cancellationReason ? detailRow("Motivo", appointment.cancellationReason) : ""}
              </div>
            </section>
          ` : ""}

          ${actionMarkup ? `<div class="appointment-detail-panel__actions">${actionMarkup}</div>` : ""}
        </div>
      </section>

      ${appointment.depositReceiptPreviewUrl ? `
        <dialog class="appointment-detail-panel__receipt-dialog" data-appointment-detail-receipt-dialog>
          <button type="button" data-appointment-detail-receipt-close aria-label="Cerrar comprobante">×</button>
          <img src="${escapeAttribute(appointment.depositReceiptPreviewUrl)}" alt="Comprobante subido por ${escapeAttribute(appointment.client || "el cliente")}">
        </dialog>
      ` : ""}
    </div>
  `
}

export function bindAppointmentDetailPanel(root, { onSaveNotes, onCancel, onChangeServiceVariant } = {}) {
  const dialog = root.querySelector("[data-appointment-detail-receipt-dialog]")
  const previewButton = root.querySelector("[data-appointment-detail-receipt-preview]")
  const closeButton = root.querySelector("[data-appointment-detail-receipt-close]")
  if (dialog && previewButton && closeButton) {
    previewButton.addEventListener("click", () => dialog.showModal())
    closeButton.addEventListener("click", () => dialog.close())
    dialog.addEventListener("click", (event) => {
      if (event.target === dialog) dialog.close()
    })
  }

  const notesForm = root.querySelector("[data-appointment-detail-notes-form]")
  const notesEditButton = root.querySelector("[data-appointment-detail-notes-edit]")
  const notesCancelButton = root.querySelector("[data-appointment-detail-notes-cancel]")
  const notesInput = root.querySelector("[data-appointment-detail-notes-input]")
  const notesError = root.querySelector("[data-appointment-detail-notes-error]")
  const notesSaveButton = root.querySelector("[data-appointment-detail-notes-save]")

  const cancelButton = root.querySelector("[data-appointment-detail-cancel]")
  if (cancelButton) {
    cancelButton.addEventListener("click", () => {
      openCancellationDialog({
        onConfirm: async (reason) => {
          if (!onCancel) throw new Error("No se pudo cancelar el turno.")
          await onCancel(reason)
        }
      })
    })
  }

  const variantSelect = root.querySelector("[data-appointment-detail-service-variant]")
  const variantError = root.querySelector("[data-appointment-detail-service-variant-error]")
  variantSelect?.addEventListener("change", async () => {
    variantSelect.disabled = true
    variantError?.classList.add("hidden")
    try {
      await onChangeServiceVariant?.(variantSelect.value)
    } catch (error) {
      if (variantError) {
        variantError.textContent = error.message || "No se pudo cambiar el tamaño."
        variantError.classList.remove("hidden")
      }
      variantSelect.disabled = false
    }
  })

  if (!notesForm || !notesInput || !onSaveNotes) return

  const initialNotesValue = () => notesForm.dataset.initialNotes || ""
  const notesChanged = () => notesInput.value !== initialNotesValue()
  const syncNotesActions = () => {
    if (notesSaveButton) {
      notesSaveButton.hidden = !notesChanged()
      notesSaveButton.disabled = false
      notesSaveButton.textContent = "Guardar"
    }
  }

  syncNotesActions()

  notesEditButton?.addEventListener("click", () => {
    notesForm.hidden = false
    notesEditButton.hidden = true
    syncNotesActions()
    notesInput.focus()
  })

  notesInput.addEventListener("input", () => {
    if (notesError) {
      notesError.textContent = ""
      notesError.classList.add("hidden")
    }
    syncNotesActions()
  })

  notesCancelButton?.addEventListener("click", () => {
    notesInput.value = initialNotesValue()
    if (notesForm.dataset.hasNotes !== "true") {
      notesForm.hidden = true
      if (notesEditButton) notesEditButton.hidden = false
    }
    if (notesError) {
      notesError.textContent = ""
      notesError.classList.add("hidden")
    }
    syncNotesActions()
  })

  notesSaveButton?.addEventListener("click", async () => {
    if (!notesChanged()) {
      syncNotesActions()
      return
    }

    if (notesError) {
      notesError.textContent = ""
      notesError.classList.add("hidden")
    }
    if (notesSaveButton) {
      notesSaveButton.disabled = true
      notesSaveButton.textContent = "Guardando..."
    }

    try {
      await onSaveNotes(notesInput.value)
    } catch (error) {
      if (notesError) {
        notesError.textContent = error.message || "No pudimos guardar las notas."
        notesError.classList.remove("hidden")
      }
      if (notesSaveButton?.isConnected) {
        notesSaveButton.disabled = false
        notesSaveButton.textContent = "Guardar"
      }
    }
  })
}

export function openCancellationDialog({ onConfirm }) {
  const dialog = document.createElement("dialog")
  dialog.className = "appointment-cancel-dialog"
  dialog.innerHTML = `
    <div class="appointment-cancel-dialog__body">
      <div class="appointment-cancel-dialog__header">
        <h2>¿Cancelar turno?</h2>
        <button type="button" class="appointment-cancel-dialog__close" data-appointment-cancel-close aria-label="Cerrar">×</button>
      </div>
      <p class="appointment-cancel-dialog__copy">El horario se liberará y el turno quedará registrado en el historial del cliente.</p>
      <label class="appointment-cancel-dialog__label" for="appointmentCancelReason">
        Motivo de la cancelación
        <textarea id="appointmentCancelReason" class="appointment-cancel-dialog__reason" maxlength="1000" required placeholder="Ej.: El centro permanecerá cerrado ese día."></textarea>
      </label>
      <p class="appointment-cancel-dialog__error" data-appointment-cancel-error hidden></p>
      <div class="appointment-cancel-dialog__actions">
        <button type="button" data-appointment-cancel-dismiss>Volver</button>
        <button type="button" data-appointment-cancel-confirm>Confirmar cancelación</button>
      </div>
    </div>
  `
  document.body.append(dialog)

  const close = () => {
    if (dialog.open) dialog.close()
  }
  const confirmButton = dialog.querySelector("[data-appointment-cancel-confirm]")
  const errorBox = dialog.querySelector("[data-appointment-cancel-error]")

  dialog.querySelector("[data-appointment-cancel-close]").addEventListener("click", close)
  dialog.querySelector("[data-appointment-cancel-dismiss]").addEventListener("click", close)
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) close()
  })
  dialog.addEventListener("close", () => dialog.remove(), { once: true })
  dialog.showModal()

  confirmButton.addEventListener("click", async () => {
    const reason = dialog.querySelector("#appointmentCancelReason")?.value.trim() || ""
    errorBox.hidden = true
    if (!reason) {
      errorBox.textContent = "Indicá el motivo de la cancelación."
      errorBox.hidden = false
      return
    }

    confirmButton.disabled = true
    confirmButton.textContent = "Cancelando..."
    try {
      await onConfirm(reason)
      close()
    } catch (error) {
      errorBox.textContent = error.message || "No se pudo cancelar el turno."
      errorBox.hidden = false
      confirmButton.disabled = false
      confirmButton.textContent = "Confirmar cancelación"
    }
  })
}

export async function openProfessionalPicker({ professionalsUrl, selectedProfessionalId, onConfirm }) {
  const dialog = document.createElement("dialog")
  dialog.className = "appointment-professional-picker"
  dialog.innerHTML = `
    <div class="appointment-professional-picker__header">
      <div>
        <p>ASIGNACIÓN DEL TURNO</p>
        <h2>Cambiar profesional</h2>
      </div>
      <button type="button" data-appointment-professional-picker-close aria-label="Cerrar">×</button>
    </div>
    <div class="appointment-professional-picker__body">
      <p class="appointment-professional-picker__hint">Elegí una persona habilitada para realizar este servicio.</p>
      <div class="appointment-professional-picker__list" data-appointment-professional-picker-list>
        <p class="appointment-professional-picker__loading">Cargando profesionales…</p>
      </div>
      <p class="appointment-professional-picker__error hidden" data-appointment-professional-picker-error></p>
      <div class="appointment-professional-picker__actions">
        <button type="button" data-appointment-professional-picker-cancel>Cancelar</button>
        <button type="button" data-appointment-professional-picker-confirm disabled>Confirmar cambio</button>
      </div>
    </div>
  `
  document.body.append(dialog)

  const close = () => dialog.close()
  const list = dialog.querySelector("[data-appointment-professional-picker-list]")
  const errorBox = dialog.querySelector("[data-appointment-professional-picker-error]")
  const confirmButton = dialog.querySelector("[data-appointment-professional-picker-confirm]")
  let selectedId = String(selectedProfessionalId || "")

  dialog.querySelector("[data-appointment-professional-picker-close]").addEventListener("click", close)
  dialog.querySelector("[data-appointment-professional-picker-cancel]").addEventListener("click", close)
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) close()
  })
  dialog.addEventListener("close", () => dialog.remove(), { once: true })
  dialog.showModal()

  try {
    const response = await fetch(professionalsUrl, { headers: { Accept: "application/json" } })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(Array.isArray(payload.errors) ? payload.errors.join(". ") : "No pudimos cargar los profesionales.")

    const professionals = Array.isArray(payload.professionals) ? payload.professionals : []
    if (!professionals.length) {
      list.innerHTML = '<p class="appointment-professional-picker__empty">No hay profesionales habilitados para este servicio.</p>'
      return
    }

    const render = () => {
      list.innerHTML = professionals.map((professional) => {
        const id = String(professional.id)
        const selected = id === selectedId
        return `
          <button type="button" class="appointment-professional-picker__option${selected ? " is-selected" : ""}" data-appointment-professional-picker-option data-professional-id="${escapeAttribute(id)}">
            <span class="appointment-professional-picker__avatar">${escapeHTML(professional.initials || initials(professional.name))}</span>
            <span><strong>${escapeHTML(professional.name)}</strong><small>${escapeHTML([professional.specialty, professional.branchName].filter(Boolean).join(" · ") || "Profesional")}</small></span>
            ${selected ? "<b>Actual</b>" : ""}
          </button>
        `
      }).join("")
      list.querySelectorAll("[data-appointment-professional-picker-option]").forEach((option) => {
        option.addEventListener("click", () => {
          selectedId = option.dataset.professionalId
          confirmButton.disabled = selectedId === String(selectedProfessionalId || "")
          render()
        })
      })
    }

    confirmButton.disabled = selectedId === String(selectedProfessionalId || "")
    render()
  } catch (error) {
    list.innerHTML = ""
    errorBox.textContent = error.message || "No pudimos cargar los profesionales."
    errorBox.classList.remove("hidden")
  }

  confirmButton.addEventListener("click", async () => {
    if (!selectedId) return

    errorBox.classList.add("hidden")
    confirmButton.disabled = true
    confirmButton.textContent = "Guardando..."
    try {
      await onConfirm(selectedId)
      dialog.close()
    } catch (error) {
      errorBox.textContent = error.message || "No se pudo cambiar el profesional."
      errorBox.classList.remove("hidden")
      confirmButton.disabled = false
      confirmButton.textContent = "Confirmar cambio"
    }
  })
}
