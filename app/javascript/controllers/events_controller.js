import { Controller } from "@hotwired/stimulus"
import { cachedKeys, cacheKeys, pull, push, merge } from "bookmark_store"

const STORAGE_KEY = "ibk-dashboard-filter"

// Client-side event filtering along ONE dimension at a time. The nav offers
// "Alle", "Kategorie"/"Venue" (which expand a chip panel below; clicking
// again collapses it) and "Gemerkt" (bookmarked events).
// Picking a chip or "Gemerkt" replaces the nav with a back button plus the
// active selection; back returns to "Alle".
// The filter is read from the URL (shareable) or localStorage (returning
// visitors). Bookmarks live in an anonymous backend list (bookmark_store);
// opening a ?sync= link merges this browser's list with the shared one.
export default class extends Controller {
  static targets = [
    "event", "dateGroup", "dateLink", "panel", "navRow", "navButton",
    "selectionBar", "selectionLabel", "shareButton", "bookmarkButton",
    "emptyMessage", "stickyHeader"
  ]

  connect() {
    this.bookmarks = cachedKeys()
    // Stashed before apply(), whose persist() rewrites the URL without it.
    this.syncToken = new URLSearchParams(window.location.search).get("sync")
    const { mode, value } = this.initialFilter()
    this.mode = mode
    this.value = value
    this.expandedPanel = null
    this.selectedDate = window.location.hash.startsWith("#date-") ? window.location.hash : null
    this.markBookmarkButtons()
    this.apply()
    this.syncBookmarks()

    // The sticky filter block's height varies (wrapping chips, selection bar),
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
    if (params.has("gemerkt")) return { mode: "bookmarked", value: null }
    // links shared before the one-dimensional filter
    if (params.has("organizations[]")) return { mode: "venue", value: params.get("organizations[]") }

    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY))
      if (stored?.mode === "bookmarked") return { mode: "bookmarked", value: null }
      if (stored?.mode && stored.value) return { mode: stored.mode, value: stored.value }
    } catch {
      // fall through to the default
    }

    return { mode: "all", value: null }
  }

  showAll() {
    this.mode = "all"
    this.value = null
    this.expandedPanel = null
    this.apply()
  }

  // "Kategorie" / "Venue" don't filter by themselves — they expand and
  // collapse their chip panel.
  togglePanel(event) {
    const mode = event.currentTarget.dataset.mode
    this.expandedPanel = this.expandedPanel === mode ? null : mode
    this.apply()
  }

  selectChip(event) {
    this.mode = event.currentTarget.dataset.mode
    this.value = event.currentTarget.dataset.value
    this.expandedPanel = null
    this.apply()
  }

  selectBookmarked() {
    this.mode = "bookmarked"
    this.value = null
    this.expandedPanel = null
    this.apply()
  }

  // Reconcile with the backend after the cache already painted: a ?sync=
  // link merges this browser's list with the shared one (and jumps to
  // "Gemerkt" so the result is visible), otherwise the list is pulled fresh.
  async syncBookmarks() {
    const synced = this.syncToken ? await merge(this.syncToken) : await pull()
    const viaLink = this.syncToken !== null
    this.syncToken = null
    if (!synced) return

    this.bookmarks = synced.keys
    this.markBookmarkButtons()
    if (viaLink) this.selectBookmarked()
    else if (this.mode === "bookmarked") this.apply()
  }

  // The button sits inside the event's link, so the click must not navigate.
  // The UI updates optimistically; the backend write happens in the
  // background and the cache covers any failure until the next sync.
  toggleBookmark(event) {
    event.preventDefault()
    event.stopPropagation()

    const key = event.currentTarget.closest("[data-events-target~=event]").dataset.bookmarkKey
    const adding = !this.bookmarks.has(key)
    adding ? this.bookmarks.add(key) : this.bookmarks.delete(key)
    cacheKeys(this.bookmarks)
    push(adding ? { add: [key] } : { remove: [key] })

    this.markBookmarkButtons()
    if (this.mode === "bookmarked") this.apply()
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
      const matches =
        this.mode === "bookmarked" ? this.bookmarks.has(el.dataset.bookmarkKey) :
        !this.value ? true :
        (this.mode === "category" ? el.dataset.category : el.dataset.organization) === this.value
      el.classList.toggle("hidden", !matches)
    })

    this.dateGroupTargets.forEach((group) => {
      const hasVisibleEvents = group.querySelector("[data-events-target~=event]:not(.hidden)") !== null
      group.classList.toggle("hidden", !hasVisibleEvents)
    })

    this.markDateLinks()
    this.updateNav()

    const anythingVisible = this.dateGroupTargets.some((group) => !group.classList.contains("hidden"))
    this.emptyMessageTarget.classList.toggle("hidden", anythingVisible)

    this.persist()
    this.highlightCurrentDate()
  }

  // While a filter is selected the nav row gives way to the selection bar
  // (back button + active selection); otherwise the nav row shows, with the
  // expanded panel's button highlighted ("Alle" when none is).
  updateNav() {
    const selected = this.mode === "bookmarked" || this.value !== null

    this.navRowTarget.classList.toggle("hidden", selected)
    this.navRowTarget.classList.toggle("flex", !selected)
    this.selectionBarTarget.classList.toggle("hidden", !selected)
    this.selectionBarTarget.classList.toggle("flex", selected)
    this.selectionLabelTarget.textContent = this.mode === "bookmarked" ? "Gemerkt" : this.value
    this.shareButtonTarget.classList.toggle("hidden", this.mode !== "bookmarked")

    this.navButtonTargets.forEach((button) => {
      const active = (this.expandedPanel ?? "all") === button.dataset.mode
      button.classList.toggle("bg-gray-900", active)
      button.classList.toggle("text-white", active)

      const chevron = button.querySelector("svg")
      if (chevron) {
        const expanded = this.expandedPanel === button.dataset.mode
        chevron.classList.toggle("rotate-180", expanded)
        button.setAttribute("aria-expanded", expanded)
      }
    })

    this.panelTargets.forEach((panel) => {
      const show = !selected && panel.dataset.mode === this.expandedPanel
      panel.classList.toggle("flex", show)
      panel.classList.toggle("hidden", !show)
    })
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
      link.classList.toggle("bg-gray-900", active)
      link.classList.toggle("border-gray-900", active)
      link.classList.toggle("text-white", active)
      link.classList.toggle("bg-white", !active)
      const weekday = link.querySelector("span")
      weekday.classList.toggle("text-gray-500", !active)
      weekday.classList.toggle("text-gray-300", active)
    })
  }

  markBookmarkButtons() {
    this.bookmarkButtonTargets.forEach((button) => {
      const key = button.closest("[data-events-target~=event]").dataset.bookmarkKey
      const on = this.bookmarks.has(key)
      button.classList.toggle("text-gray-300", !on)
      button.classList.toggle("hover:text-gray-500", !on)
      button.classList.toggle("text-gray-900", on)
      button.querySelector("svg").classList.toggle("fill-current", on)
      button.setAttribute("aria-pressed", on)
    })
  }

  persist() {
    const params = new URLSearchParams()
    if (this.mode === "bookmarked") params.set("gemerkt", "1")
    else if (this.value) params.set(this.mode, this.value)
    const query = params.toString()
    const url = `${window.location.pathname}${query ? `?${query}` : ""}${this.selectedDate ?? ""}`
    window.history.replaceState(null, "", url)

    localStorage.setItem(STORAGE_KEY, JSON.stringify({ mode: this.mode, value: this.value }))
  }
}
