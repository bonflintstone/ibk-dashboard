import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "ibk-dashboard-organizations"

// Client-side event filtering: categories act as tabs, and the active
// category's venues can be toggled individually. No category ("Alle") with an
// empty selection means "show everything".
// Selection is read from the URL (shareable) or localStorage (returning visitors).
export default class extends Controller {
  static targets = [
    "event", "dateGroup", "dateLink", "chip", "categoryChip", "allChip",
    "venuePanel", "emptyMessage", "stickyHeader"
  ]
  static values = { defaultSelection: Array }

  connect() {
    this.selected = new Set(this.initialSelection())
    this.category = this.deriveCategory()
    this.apply()

    // The sticky filter block's height varies (wrapping chips, toggled panel),
    // so the date headings' sticky offset is kept in a CSS variable.
    this.resizeObserver = new ResizeObserver(() => this.updateStickyOffset())
    this.resizeObserver.observe(this.stickyHeaderTarget)
    this.updateStickyOffset()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  updateStickyOffset() {
    this.element.style.setProperty("--filter-height", `${this.stickyHeaderTarget.offsetHeight}px`)
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

  // The category isn't persisted; it's recovered from whichever category
  // contains all selected venues. Cross-category selections (e.g. from an old
  // shared URL) still filter, they just don't light up a category tab.
  deriveCategory() {
    if (this.selected.size === 0) return null

    const match = this.categoryChipTargets.find((chip) => {
      const organizations = JSON.parse(chip.dataset.organizations)
      return [...this.selected].every((organization) => organizations.includes(organization))
    })
    return match ? match.dataset.category : null
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
    this.category = event.currentTarget.dataset.category
    this.selected = new Set(JSON.parse(event.currentTarget.dataset.organizations))
    this.apply()
  }

  showAll() {
    this.category = null
    this.selected.clear()
    this.apply()
  }

  apply() {
    const showEverything = this.selected.size === 0 && !this.category

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

    this.venuePanelTarget.classList.toggle("hidden", !this.category)
    this.chipTargets.forEach((chip) => {
      chip.classList.toggle("hidden", chip.dataset.category !== this.category)
      this.markChip(chip, this.selected.has(chip.dataset.organization))
    })

    this.categoryChipTargets.forEach((chip) => {
      this.markChip(chip, chip.dataset.category === this.category)
    })

    this.markChip(this.allChipTarget, showEverything)

    const anythingVisible = this.dateGroupTargets.some((group) => !group.classList.contains("hidden"))
    this.emptyMessageTarget.classList.toggle("hidden", anythingVisible)

    this.persist()
  }

  markChip(chip, active) {
    chip.classList.toggle("bg-gray-900", active)
    chip.classList.toggle("border-gray-900", active)
    chip.classList.toggle("text-white", active)
    chip.classList.toggle("bg-white", !active)
  }

  persist() {
    const params = new URLSearchParams()
    this.selected.forEach((organization) => params.append("organizations[]", organization))
    const query = params.toString()
    window.history.replaceState(null, "", query ? `?${query}` : window.location.pathname)

    localStorage.setItem(STORAGE_KEY, JSON.stringify([...this.selected]))
  }
}
