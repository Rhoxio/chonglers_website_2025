import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { autoHide: Number }

  connect() {
    if (this.autoHideValue > 0) {
      this.timeout = setTimeout(() => {
        this.close()
      }, this.autoHideValue)
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  close() {
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-20px)'

    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}