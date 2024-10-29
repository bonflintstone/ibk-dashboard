import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["event"]

  toggleOrganization(event) {
    const organization = event.target.value
    const hiding = !event.target.checked

    this.eventTargets
      .filter(({ dataset }) => dataset.organization === organization)
      .forEach(({ classList }) => hiding ? classList.add('hidden') : classList.remove('hidden'))
  }
}
