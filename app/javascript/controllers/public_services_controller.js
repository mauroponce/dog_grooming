import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "item", "empty", "tab", "rail", "sheet", "heading"]
  static values = { initialCategory: String, persistCategory: Boolean }

  connect() {
    this.category = this.initialCategory
    this.updateTabs()
    this.updateHeading()
    this.filter()
    requestAnimationFrame(() => this.scrollSelectedTabIntoView("auto"))
  }

  disconnect() {
    this.closeCategories()
  }

  search() {
    this.filter()
  }

  selectCategory(event) {
    this.category = event.currentTarget.dataset.category
    this.updateTabs()
    this.updateHeading()
    this.filter()
    this.scrollSelectedTabIntoView()
    this.persistCategoryInUrl()
    this.closeCategories()
  }

  openCategories() {
    if (!this.hasSheetTarget) return

    this.sheetTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  closeCategories() {
    if (!this.hasSheetTarget) return

    this.sheetTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  filter() {
    const query = this.hasQueryTarget ? this.normalize(this.queryTarget.value) : ""
    let visibleCount = 0

    this.itemTargets.forEach((item) => {
      const categories = (item.dataset.category || "").split("|")
      const matchesCategory = this.category === "Todos" || categories.includes(this.category)
      const matchesQuery = this.normalize(item.dataset.search).includes(query)
      const visible = matchesCategory && matchesQuery
      item.classList.toggle("hidden", !visible)
      if (visible) visibleCount += 1
    })

    this.emptyTarget.classList.toggle("hidden", visibleCount > 0)
  }

  updateTabs() {
    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.category === this.category
      tab.className = selected ? this.selectedTabClasses : this.idleTabClasses
    })
  }

  updateHeading() {
    if (this.hasHeadingTarget) this.headingTarget.textContent = this.category === "Todos" ? "Servicio" : this.category
  }

  scrollSelectedTabIntoView(behavior = "smooth") {
    const selectedTab = this.tabTargets.find((tab) => tab.dataset.category === this.category)
    const rail = selectedTab?.closest("[data-public-services-target='rail']")
    if (!selectedTab || !rail) return

    const selectedTabRect = selectedTab.getBoundingClientRect()
    const railRect = rail.getBoundingClientRect()
    const desiredLeft = rail.scrollLeft + selectedTabRect.left - railRect.left - ((rail.clientWidth - selectedTabRect.width) / 2)
    const maxLeft = Math.max(rail.scrollWidth - rail.clientWidth, 0)

    rail.scrollTo({
      left: Math.min(Math.max(desiredLeft, 0), maxLeft),
      behavior
    })
  }

  get selectedTabClasses() {
    return "shrink-0 rounded-full bg-zinc-950 px-4 py-2 text-sm font-bold text-white"
  }

  get idleTabClasses() {
    return "shrink-0 rounded-full border border-zinc-200 bg-white px-4 py-2 text-sm font-bold text-zinc-800 transition hover:border-zinc-950"
  }

  get initialCategory() {
    if (this.hasInitialCategoryValue && this.tabTargets.some((tab) => tab.dataset.category === this.initialCategoryValue)) {
      return this.initialCategoryValue
    }

    const allTab = this.tabTargets.find((tab) => tab.dataset.category === "Todos")
    return allTab?.dataset.category || this.tabTargets[0]?.dataset.category || "Todos"
  }

  persistCategoryInUrl() {
    if (!this.persistCategoryValue) return

    const url = new URL(window.location.href)
    url.searchParams.set("category", this.category)
    window.history.replaceState(window.history.state, "", url)
  }

  normalize(value) {
    return value.toString().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase()
  }
}
