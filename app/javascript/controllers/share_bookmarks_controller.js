import { Controller } from "@hotwired/stimulus"
import { storedToken, push } from "bookmark_store"

// Fills the footer's share modal (opened by the modal controller alongside):
// makes sure this browser's bookmark list exists in the backend, then shows
// the sync link and its QR code. Opening that link on another device merges
// the two lists into one shared by both. Also offers the list's personal
// calendar feed (webcal:// opens straight in Apple Calendar & co.).
export default class extends Controller {
  static targets = ["link", "qr", "copyButton", "error", "calendarLink", "copyCalendarButton"]

  async prepare() {
    // No list yet: create one, seeded with whatever is bookmarked locally.
    const token = storedToken() ?? (await push())?.token
    if (!token) {
      this.errorTarget.classList.remove("hidden")
      return
    }

    this.errorTarget.classList.add("hidden")
    this.url = `${window.location.origin}/?sync=${encodeURIComponent(token)}`
    this.linkTarget.textContent = this.url
    this.qrTarget.src = `/bookmarks/qr?token=${encodeURIComponent(token)}`

    this.calendarUrl = `${window.location.origin}/bookmarks/calendar.ics?token=${encodeURIComponent(token)}`
    this.calendarLinkTarget.href = this.calendarUrl.replace(/^https?:/, "webcal:")
  }

  async copy() {
    if (!this.url) return
    await navigator.clipboard.writeText(this.url)
    this.copyButtonTarget.textContent = "Kopiert!"
    setTimeout(() => { this.copyButtonTarget.textContent = "Link kopieren" }, 2000)
  }

  // For calendar apps without webcal support (e.g. Google Calendar's
  // "Per URL" dialog), which want the https URL pasted in.
  async copyCalendar() {
    if (!this.calendarUrl) return
    await navigator.clipboard.writeText(this.calendarUrl)
    this.copyCalendarButtonTarget.textContent = "Kopiert!"
    setTimeout(() => { this.copyCalendarButtonTarget.textContent = "Kalender-Link kopieren" }, 2000)
  }
}
