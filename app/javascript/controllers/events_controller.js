import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "ibk-dashboard-filter"

// Client-side event filtering along ONE dimension at a time: a three-way
// mode toggle switches between no filter ("Alle"), filtering by category and
// filtering by venue; within category/venue at most one chip is selected
// (tapping the active chip deselects it). On mobile the chip row is
// collapsed behind an arrow by default.
// The filter is read from the URL (shareable) or localStorage (returning visitors).
export default class extends Controller {
  static targets = [
    "event", "dateGroup", "dateLink", "chip", "modeChip", "panel",
    "emptyMessage", "stickyHeader", "chipsRow", "chipsArrow"
  ]

  connect() {
    const { mode, value } = this.initialFilter()
    this.mode = mode
    this.value = value
    this.chipsExpanded = false
    this.selectedDate = window.location.hash.startsWith("#date-") ? window.location.hash : null
    this.apply()

    // The sticky filter block's height varies (wrapping chips, mode switch),
    // so the date sections' anchor scroll offset is kept in a CSS variable.
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
  // URL beats the user's saved filter; the default is no filter.
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

    return { mode: "all", value: null }
  }

  selectMode(event) {
    this.mode = event.currentTarget.dataset.mode
    this.value = null
    // Picking a chip mode is a clear intent to filter, so reveal the chips
    // even on mobile, where they start out collapsed.
    this.chipsExpanded = this.mode !== "all"
    this.apply()
  }

  toggleChips() {
    this.chipsExpanded = !this.chipsExpanded
    this.updateChipsRow()
  }

  // Tapping the active chip deselects it (back to "Alle").
  selectChip(event) {
    const value = event.currentTarget.dataset.value
    this.value = this.value === value ? null : value
    this.apply()
  }

  selectDate(event) {
    this.selectedDate = event.currentTarget.getAttribute("href")
    this.markDateLinks()
    this.persist()
  }

  // The highlight in the date nav follows the scroll position: the topmost
  // day under the filter bar is marked and kept scrolled into view.
  highlightCurrentDate() {
    const offset = this.stickyHeaderTarget.getBoundingClientRect().bottom + 8
    const groups = this.dateGroupTargets.filter((group) => !group.classList.contains("hidden"))
    const current = groups.findLast((group) => group.getBoundingClientRect().top <= offset) ?? groups[0]
    if (!current) return

    const href = `#${current.id}`
    if (href === this.selectedDate) return
    this.selectedDate = href
    this.markDateLinks()

    const link = this.dateLinkTargets.find((l) => l.getAttribute("href") === href)
    link?.scrollIntoView({ block: "nearest", inline: "center", behavior: "smooth" })
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

    this.markDateLinks()

    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.mode !== this.mode)
    })

    this.chipTargets.forEach((chip) => {
      this.markChip(chip, chip.dataset.mode === this.mode && chip.dataset.value === this.value)
    })

    this.updateChipsRow()

    this.modeChipTargets.forEach((chip) => {
      const active = chip.dataset.mode === this.mode
      chip.classList.toggle("bg-gray-900", active)
      chip.classList.toggle("text-white", active)
    })

    const anythingVisible = this.dateGroupTargets.some((group) => !group.classList.contains("hidden"))
    this.emptyMessageTarget.classList.toggle("hidden", anythingVisible)

    this.persist()
    this.highlightCurrentDate()
  }

  // Days without matching events stay visible but grayed out and unclickable;
  // the day currently scrolled into view is highlighted.
  markDateLinks() {
    this.dateLinkTargets.forEach((link) => {
      const group = document.getElementById(link.getAttribute("href").slice(1))
      const empty = !group || group.classList.contains("hidden")
      link.classList.toggle("pointer-events-none", empty)
      link.classList.toggle("opacity-40", empty)
      link.toggleAttribute("aria-disabled", empty)

      const active = link.getAttribute("href") === this.selectedDate
      this.markChip(link, active)
      const weekday = link.querySelector("span")
      weekday.classList.toggle("text-gray-500", !active)
      weekday.classList.toggle("text-gray-300", active)
    })
  }

  // In "Alle" mode there are no chips, so the row and its arrow disappear.
  // Otherwise the row always shows on desktop (sm:flex) and on mobile only
  // when expanded via the arrow.
  updateChipsRow() {
    const hasChips = this.mode !== "all"
    this.chipsRowTarget.classList.toggle("sm:flex", hasChips)
    this.chipsRowTarget.classList.toggle("flex", hasChips && this.chipsExpanded)
    this.chipsRowTarget.classList.toggle("hidden", !hasChips || !this.chipsExpanded)

    this.chipsArrowTarget.classList.toggle("hidden", !hasChips)
    this.chipsArrowTarget.setAttribute("aria-expanded", this.chipsExpanded)
    this.chipsArrowTarget.querySelector("svg").classList.toggle("rotate-180", this.chipsExpanded)
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
    const url = `${window.location.pathname}${query ? `?${query}` : ""}${this.selectedDate ?? ""}`
    window.history.replaceState(null, "", url)

    localStorage.setItem(STORAGE_KEY, JSON.stringify({ mode: this.mode, value: this.value }))
  }
}
