import { Controller } from "@hotwired/stimulus"

// Two-step new-event form: the submitter enters a link, we fetch the page and
// extract the remaining fields with the Claude API, then reveal them for review
// and correction. "manuell ausfüllen" skips the fetch and reveals empty fields.
export default class extends Controller {
  static targets = ["link", "details", "status", "loadButton", "manualButton",
                    "name", "location", "datetime", "description"]
  static values = { extractUrl: String }

  async load() {
    const link = this.linkTarget.value.trim()
    if (!link) {
      this.showStatus("Bitte zuerst einen Link eingeben.")
      this.linkTarget.focus()
      return
    }

    this.loadButtonTarget.disabled = true
    this.loadButtonTarget.textContent = "Lädt…"
    this.showStatus("Seite wird ausgelesen…")

    try {
      const response = await fetch(this.extractUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        },
        body: JSON.stringify({ link })
      })
      const data = await response.json()

      if (response.ok) {
        this.fill(data)
        this.reveal()
        this.hideStatus()
      } else {
        // Extraction failed — let them fill it in by hand instead of dead-ending.
        this.reveal()
        this.showStatus(data.error || "Konnte die Seite nicht auslesen.")
      }
    } catch {
      this.reveal()
      this.showStatus("Konnte die Seite nicht auslesen. Bitte fülle die Felder manuell aus.")
    } finally {
      this.loadButtonTarget.disabled = false
      this.loadButtonTarget.textContent = "Aus Link befüllen"
    }
  }

  manual() {
    this.reveal()
    this.hideStatus()
    this.nameTarget.focus()
  }

  fill(data) {
    for (const field of ["name", "location", "datetime", "description"]) {
      if (data[field]) this[`${field}Target`].value = data[field]
    }
  }

  reveal() {
    this.detailsTarget.classList.remove("hidden")
    this.detailsTarget.classList.add("flex")
    this.manualButtonTarget.classList.add("hidden")
  }

  showStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
  }

  hideStatus() {
    this.statusTarget.classList.add("hidden")
  }
}
