import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["event"]

  toggleOrganization(event) {
    const organization = event.target.dataset.organization
    const hiding = event.target.dataset.hidden !== 'true'

    event.target.dataset.hidden = hiding ? 'true' : 'false'

    this.eventTargets
      .filter(({ dataset }) => dataset.organization === organization)
      .forEach(({ classList }) => hiding ? classList.add('hidden') : classList.remove('hidden'))
  }
}
