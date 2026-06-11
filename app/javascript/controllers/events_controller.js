import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "ibk-dashboard-filter"

// Client-side event filtering: categories act as tabs, and within the active
// category individual venues can be toggled to narrow further (no venue
// selected = the whole category). "Alle" shows everything.
// The filter is read from the URL (shareable) or localStorage (returning visitors).
export default class extends Controller {
  static targets = [
    "event", "dateGroup", "dateLink", "chip", "categoryChip", "allChip",
    "venuePanel", "emptyMessage", "stickyHeader"
  ]

  connect() {
    const { category, organizations } = this.initialFilter()
    this.category = category
    this.selected = new Set(organizations)
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

  // URL beats the user's saved filter; the default is "Alle".
  initialFilter() {
    const params = new URLSearchParams(window.location.search)
    if (params.has("category") || params.has("organizations[]")) {
      return { category: params.get("category"), organizations: params.getAll("organizations[]") }
    }

    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY))
      if (stored && !Array.isArray(stored)) {
        return { category: stored.category ?? null, organizations: stored.organizations ?? [] }
      }
    } catch {
      // fall through to the default
    }

    return { category: null, organizations: [] }
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

  selectCategory(event) {
    this.category = event.currentTarget.dataset.category
    this.selected.clear()
    this.apply()
  }

  showAll() {
    this.category = null
    this.selected.clear()
    this.apply()
  }

  apply() {
    this.eventTargets.forEach((el) => {
      const categoryMatches = !this.category || el.dataset.category === this.category
      const organizationMatches = this.selected.size === 0 || this.selected.has(el.dataset.organization)
      el.classList.toggle("hidden", !(categoryMatches && organizationMatches))
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

    this.markChip(this.allChipTarget, !this.category)

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
    if (this.category) params.set("category", this.category)
    this.selected.forEach((organization) => params.append("organizations[]", organization))
    const query = params.toString()
    window.history.replaceState(null, "", query ? `?${query}` : window.location.pathname)

    localStorage.setItem(STORAGE_KEY, JSON.stringify({
      category: this.category,
      organizations: [...this.selected]
    }))
  }
}
