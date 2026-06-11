import { Controller } from "@hotwired/stimulus"

// The dialog is opened non-modally (show(), not showModal()) so it stays out
// of the browser's top layer — otherwise the hCaptcha challenge popup would
// render behind it. Backdrop and Esc handling are therefore done by hand.
export default class extends Controller {
  static targets = ["dialog", "backdrop"]

  open(event) {
    event.preventDefault()
    this.dialogTarget.show()
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.dialogTarget.close()
    this.backdropTarget.classList.add("hidden")
  }
}
