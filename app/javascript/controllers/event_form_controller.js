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

    // The server checks the captcha before the (paid) extraction, so an
    // unsolved captcha would only waste a round trip.
    const captchaToken = this.element.querySelector("[name='h-captcha-response']")?.value
    if (this.element.querySelector(".h-captcha") && !captchaToken) {
      this.showStatus("Bitte löse zuerst das Captcha.")
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
        body: JSON.stringify({ link, "h-captcha-response": captchaToken })
      })
      const data = await response.json()

      if (response.ok) {
        this.fill(data)
        this.reveal()
        this.hideStatus()
      } else if (response.status === 403) {
        // Captcha rejected — keep the form as is so they can retry.
        this.showStatus(data.error || "Captcha-Prüfung fehlgeschlagen. Bitte versuche es erneut.")
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
    // Normally already rendered on modal open; harmless fallback.
    this.loadCaptcha()
  }

  // Renders the captcha when THIS form's modal opens (the modal:open event is
  // also fired by unrelated modals like the share-bookmarks one).
  prepareCaptcha(event) {
    if (!event.target.contains(this.element)) return

    this.loadCaptcha()
  }

  // hCaptcha is fetched only once someone actually opens the form, so plain
  // visitors never talk to the third party (the form modal is on every page).
  loadCaptcha() {
    const container = this.element.querySelector(".h-captcha")
    if (!container || container.querySelector("iframe")) return

    if (window.hcaptcha) {
      // Script already loaded (e.g. earlier Turbo page) — its auto-render
      // already ran, so this fresh container has to be rendered explicitly.
      window.hcaptcha.render(container)
    } else if (!document.querySelector("script[src^='https://js.hcaptcha.com/']")) {
      const script = document.createElement("script")
      script.src = "https://js.hcaptcha.com/1/api.js"
      script.async = true
      script.defer = true
      document.head.append(script)
    }
  }

  showStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
  }

  hideStatus() {
    this.statusTarget.classList.add("hidden")
  }
}
