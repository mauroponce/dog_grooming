import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "button",
    "startsAt",
    "submit",
    "summaryTime",
    "summaryTotal",
    "depositAmount",
    "balanceAmount",
    "addOn",
    "continue",
    "scheduleScreen",
    "detailsScreen",
    "stepEyebrow",
    "stepTitle",
    "stepCircle",
    "stepLabel",
    "stepItem"
  ]
  static values = { depositAmountCents: Number }

  connect() {
    this.showStep(2, { scroll: false })
    this.toggleSubmit()
    this.toggleContinue()
  }

  select(event) {
    const button = event.currentTarget
    this.buttonTargets.forEach((item) => {
      item.setAttribute("aria-pressed", "false")
      item.classList.remove("border-zinc-950", "bg-zinc-950", "text-white", "shadow-lg", "hover:border-zinc-950", "hover:bg-zinc-900")
      item.classList.add("border-brand-200", "bg-white", "text-brand-700", "hover:border-brand-500", "hover:bg-brand-50")
    })

    button.setAttribute("aria-pressed", "true")
    button.classList.remove("border-brand-200", "bg-white", "text-brand-700", "hover:border-brand-500", "hover:bg-brand-50")
    button.classList.add("border-zinc-950", "bg-zinc-950", "text-white", "shadow-lg", "hover:border-zinc-950", "hover:bg-zinc-900")

    this.startsAtTarget.value = button.dataset.slot
    if (this.hasSummaryTimeTarget) this.summaryTimeTarget.textContent = button.dataset.label
    this.basePriceCents = Number(button.dataset.priceCents || 0)
    this.updateTotal()
    this.toggleSubmit()
    this.toggleContinue()
    this.updateStepItems()
  }

  updateTotal() {
    const addOnsTotal = this.addOnTargets
      .filter((checkbox) => checkbox.checked)
      .reduce((sum, checkbox) => sum + Number(checkbox.dataset.priceCents || 0), 0)
    const total = Number(this.basePriceCents || 0) + addOnsTotal

    if (this.hasSummaryTotalTarget) {
      this.summaryTotalTargets.forEach((target) => {
        target.textContent = total > 0 ? this.formatCurrency(total) : "Consultar"
      })
    }

    if (this.hasDepositAmountTarget) {
      const deposit = Number(this.depositAmountCentsValue || 0)
      this.depositAmountTarget.textContent = deposit > 0 ? this.formatCurrency(deposit) : "Consultar"
    }

    if (this.hasBalanceAmountTarget) {
      const deposit = Number(this.depositAmountCentsValue || 0)
      const balance = Math.max(total - deposit, 0)
      this.balanceAmountTarget.textContent = total > 0 ? this.formatCurrency(balance) : "Consultar"
    }
  }

  toggleSubmit() {
    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = this.startsAtTarget.value.length === 0
  }

  toggleContinue() {
    if (!this.hasContinueTarget) return

    this.continueTarget.disabled = this.startsAtTarget.value.length === 0
  }

  continueToDetails() {
    if (!this.hasSelectedSlot()) return

    this.showStep(3)
  }

  backToSchedule() {
    this.showStep(2)
  }

  goToStep(event) {
    const step = Number(event.params.step || event.currentTarget.dataset.step)

    if (step === 2) {
      this.showStep(2)
      return
    }

    if (step === 3) this.continueToDetails()
  }

  showStep(step, options = {}) {
    this.currentStep = step

    if (this.hasScheduleScreenTarget) this.scheduleScreenTarget.classList.toggle("hidden", step !== 2)
    if (this.hasDetailsScreenTarget) this.detailsScreenTarget.classList.toggle("hidden", step !== 3)

    this.updateHeader(step)
    this.updateStepper(step)
    this.updateStepItems()

    if (options.scroll === false) return
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  updateHeader(step) {
    if (this.hasStepEyebrowTarget) {
      this.stepEyebrowTarget.textContent = step === 3 ? "Paso 4 de 5" : "Paso 3 de 5"
    }

    if (this.hasStepTitleTarget) {
      this.stepTitleTarget.textContent = step === 3 ? "Tus datos y comprobante" : "Seleccionar fecha y hora"
    }
  }

  updateStepper(currentStep) {
    if (!this.hasStepCircleTarget) return

    this.stepCircleTargets.forEach((circle) => {
      const step = Number(circle.dataset.step)
      circle.className = this.stepCircleClasses(step, currentStep)
      circle.innerHTML = step < currentStep ? this.checkIcon() : step
    })

    this.stepLabelTargets.forEach((label) => {
      const step = Number(label.dataset.step)
      label.classList.toggle("text-zinc-800", step <= currentStep)
      label.classList.toggle("text-zinc-400", step > currentStep)
    })
  }

  updateStepItems() {
    if (!this.hasStepItemTarget) return

    this.stepItemTargets.forEach((item) => {
      const step = Number(item.dataset.step)
      const canVisit = step <= this.currentStep || (step === 3 && this.hasSelectedSlot())

      if (item.tagName === "BUTTON") item.disabled = !canVisit

      item.classList.toggle("cursor-pointer", canVisit)
      item.classList.toggle("hover:bg-zinc-50", canVisit)

      if (step === this.currentStep) {
        item.setAttribute("aria-current", "step")
      } else {
        item.removeAttribute("aria-current")
      }
    })
  }

  stepCircleClasses(step, currentStep) {
    const stateClasses = step < currentStep
      ? "bg-emerald-500 text-white"
      : step === currentStep
        ? "bg-ink text-white"
        : "bg-zinc-100 text-zinc-400"

    return `grid h-8 w-8 shrink-0 place-items-center rounded-full text-xs font-bold ${stateClasses}`
  }

  checkIcon() {
    return '<svg viewBox="0 0 24 24" class="h-4 w-4" fill="none" stroke="currentColor" stroke-width="2.6"><path d="m5 12 4 4L19 6"/></svg>'
  }

  hasSelectedSlot() {
    return this.hasStartsAtTarget && this.startsAtTarget.value.length > 0
  }

  formatCurrency(cents) {
    return `$${new Intl.NumberFormat("es-AR", { maximumFractionDigits: 0 }).format(cents / 100)}`
  }
}
