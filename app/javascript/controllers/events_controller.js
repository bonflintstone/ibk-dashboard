import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "ibk-dashboard-organizations"

// Client-side event filtering: an empty selection means "show everything".
// Selection is read from the URL (shareable) or localStorage (returning visitors).
export default class extends Controller {
  static targets = [
    "event", "dateGroup", "dateLink", "chip", "categoryChip", "allChip",
    "filterPanel", "filterCount", "emptyMessage"
  ]
  static values = { defaultSelection: Array }

  connect() {
    this.selected = new Set(this.initialSelection())
    this.apply()
  }

  // URL beats the user's saved filters, saved filters beat the default.
  initialSelection() {
    const fromUrl = new URLSearchParams(window.location.search).getAll("organizations[]")
    if (fromUrl.length > 0) return fromUrl

    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored !== null) {
      try {
        return JSON.parse(stored) || []
      } catch {
        return []
      }
    }

    return this.defaultSelectionValue
  }

  toggleOrganization(event) {
    const organization = event.currentTarget.dataset.organization
    if (this.selected.has(organization)) {
      this.selected.delete(organization)
    } else {
      this.selected.add(organization)
    }
    this.apply()
  }

  // Categories behave like tabs: exactly one category's venues, or "Alle".
  selectCategory(event) {
    const organizations = JSON.parse(event.currentTarget.dataset.organizations)
    this.selected = new Set(organizations)
    this.apply()
  }

  showAll() {
    this.selected.clear()
    this.apply()
  }

  toggleFilters() {
    this.filterPanelTarget.classList.toggle("hidden")
  }

  apply() {
    const showEverything = this.selected.size === 0

    this.eventTargets.forEach((el) => {
      const visible = showEverything || this.selected.has(el.dataset.organization)
      el.classList.toggle("hidden", !visible)
    })

    this.dateGroupTargets.forEach((group) => {
      const hasVisibleEvents = group.querySelector("[data-events-target~=event]:not(.hidden)") !== null
      group.classList.toggle("hidden", !hasVisibleEvents)
    })

    this.dateLinkTargets.forEach((link) => {
      const group = document.getElementById(link.getAttribute("href").slice(1))
      link.classList.toggle("hidden", !group || group.classList.contains("hidden"))
    })

    this.chipTargets.forEach((chip) => {
      const active = this.selected.has(chip.dataset.organization)
      this.markChip(chip, active)
      chip.classList.toggle("opacity-50", !showEverything && !active)
    })

    this.categoryChipTargets.forEach((chip) => {
      const organizations = JSON.parse(chip.dataset.organizations)
      const exactMatch = organizations.length === this.selected.size &&
        organizations.every((organization) => this.selected.has(organization))
      this.markChip(chip, exactMatch)
    })

    this.markChip(this.allChipTarget, showEverything)

    this.filterCountTarget.textContent = showEverything ? "" : `(${this.selected.size})`

    const anythingVisible = this.dateGroupTargets.some((group) => !group.classList.contains("hidden"))
    this.emptyMessageTarget.classList.toggle("hidden", anythingVisible)

    this.persist()
  }

  markChip(chip, active) {
    chip.classList.toggle("ring-2", active)
    chip.classList.toggle("ring-black", active)
  }

  persist() {
    const params = new URLSearchParams()
    this.selected.forEach((organization) => params.append("organizations[]", organization))
    const query = params.toString()
    window.history.replaceState(null, "", query ? `?${query}` : window.location.pathname)

    localStorage.setItem(STORAGE_KEY, JSON.stringify([...this.selected]))
  }
}
