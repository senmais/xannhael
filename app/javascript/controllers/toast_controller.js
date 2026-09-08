import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (this.nativeApp) return

    const toast = this.element
    toast.classList.remove("opacity-0", "translate-y-2", "pointer-events-none")
    toast.classList.add("opacity-100", "translate-y-0")
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      toast.classList.add("opacity-0", "translate-y-2", "pointer-events-none")
      toast.classList.remove("opacity-100", "translate-y-0")
    }, 3000)
  }

  get nativeApp() {
    return !!document.documentElement.dataset.bridgePlatform
  }
}