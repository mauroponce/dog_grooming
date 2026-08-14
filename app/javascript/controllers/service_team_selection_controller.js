import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["all", "allFlag", "member", "row", "search", "countNumber", "countLabel"]

  connect() {
    this.syncAllFlag()
    this.updateCount()
  }

  toggleAll() {
    if (!this.hasAllTarget) return

    this.memberTargets.forEach((checkbox) => {
      checkbox.checked = this.allTarget.checked
    })
    this.syncAllFlag()
    this.updateCount()
  }

  toggleMember() {
    if (this.hasAllTarget) {
      this.allTarget.checked = this.memberTargets.length > 0 && this.memberTargets.every((checkbox) => checkbox.checked)
    }
    this.syncAllFlag()
    this.updateCount()
  }

  selectAll() {
    if (this.hasAllTarget) {
      this.allTarget.checked = true
    }
    this.memberTargets.forEach((checkbox) => {
      checkbox.checked = true
    })
    this.syncAllFlag()
    this.updateCount()
  }

  clearSearch() {
    if (!this.hasSearchTarget) return

    this.searchTarget.value = ""
    this.filter()
    this.searchTarget.focus()
  }

  filter() {
    if (!this.hasSearchTarget) return

    const query = this.normalize(this.searchTarget.value)
    this.rowTargets.forEach((row) => {
      const haystack = this.normalize(row.dataset.serviceTeamSelectionSearchValue || row.textContent)
      row.hidden = query.length > 0 && !haystack.includes(query)
    })
  }

  syncAllFlag() {
    if (this.hasAllFlagTarget && this.hasAllTarget) {
      this.allFlagTarget.value = this.allTarget.checked ? "1" : "0"
    }
  }

  updateCount() {
    if (!this.hasCountNumberTarget || !this.hasCountLabelTarget) return

    const checkedMembers = this.memberTargets.filter((checkbox) => checkbox.checked).length
    const selectedCount = this.hasAllTarget && this.allTarget.checked ? this.memberTargets.length : checkedMembers
    this.countNumberTarget.textContent = selectedCount.toString()
    this.countLabelTarget.textContent = selectedCount === 1 ? "seleccionado" : "seleccionados"
  }

  normalize(value) {
    return value
      .toString()
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
  }
}
