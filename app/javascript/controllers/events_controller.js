import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "ibk-dashboard-filter"

// Client-side event filtering along ONE dimension at a time: a mode toggle
// switches between filtering by category and filtering by venue, and within
// the active mode exactly one chip (or "Alle") can be selected.
// The filter is read from the URL (shareable) or localStorage (returning visitors).
export default class extends Controller {
  static targets = [
    "event", "dateGroup", "dateLink", "chip", "allChip", "modeChip", "panel",
    "emptyMessage", "stickyHeader"
  ]

  connect() {
    const { mode, value } = this.initialFilter()
    this.mode = mode
    this.value = value
    this.apply()

    // The sticky filter block's height varies (wrapping chips, mode switch),
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

  // URL beats the user's saved filter; the default is all categories.
  initialFilter() {
    const params = new URLSearchParams(window.location.search)
    if (params.has("category")) return { mode: "category", value: params.get("category") }
    if (params.has("venue")) return { mode: "venue", value: params.get("venue") }
    // links shared before the one-dimensional filter
    if (params.has("organizations[]")) return { mode: "venue", value: params.get("organizations[]") }

    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY))
      if (stored?.mode) return { mode: stored.mode, value: stored.value ?? null }
    } catch {
      // fall through to the default
    }

    return { mode: "category", value: null }
  }

  selectMode(event) {
    this.mode = event.currentTarget.dataset.mode
    this.value = null
    this.apply()
  }

  // Tapping the active chip deselects it (back to "Alle").
  selectChip(event) {
    const value = event.currentTarget.dataset.value
    this.value = this.value === value ? null : value
    this.apply()
  }

  showAll() {
    this.value = null
    this.apply()
  }

  apply() {
    this.eventTargets.forEach((el) => {
      const matches = !this.value ||
        (this.mode === "category" ? el.dataset.category : el.dataset.organization) === this.value
      el.classList.toggle("hidden", !matches)
    })

    this.dateGroupTargets.forEach((group) => {
      const hasVisibleEvents = group.querySelector("[data-events-target~=event]:not(.hidden)") !== null
      group.classList.toggle("hidden", !hasVisibleEvents)
    })

    this.dateLinkTargets.forEach((link) => {
      const group = document.getElementById(link.getAttribute("href").slice(1))
      link.classList.toggle("hidden", !group || group.classList.contains("hidden"))
    })

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.mode !== this.mode)
    })

    this.chipTargets.forEach((chip) => {
      this.markChip(chip, chip.dataset.mode === this.mode && chip.dataset.value === this.value)
    })

    this.allChipTargets.forEach((chip) => this.markChip(chip, !this.value))

    this.modeChipTargets.forEach((chip) => {
      const active = chip.dataset.mode === this.mode
      chip.classList.toggle("bg-gray-900", active)
      chip.classList.toggle("text-white", active)
    })

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
    if (this.value) params.set(this.mode, this.value)
    const query = params.toString()
    window.history.replaceState(null, "", query ? `?${query}` : window.location.pathname)

    localStorage.setItem(STORAGE_KEY, JSON.stringify({ mode: this.mode, value: this.value }))
  }
}
