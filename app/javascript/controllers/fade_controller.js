import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: {
      type: Number,
      default: 5000
    }
  }

  connect() {
    const element = this.element
    element.classList.add('transition-opacity')
    this.timeout = setTimeout(
      () => {
        element.classList.add('opacity-0')
        element.remove()
      },
      this.delayValue
    )
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}