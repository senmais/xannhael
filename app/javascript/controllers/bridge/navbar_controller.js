import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "navbar"

  connect() {
    super.connect()
    this.show()
  }

  show() {
    this.send("connect", { title: this.title })
  }

  hide() {
    this.send("hide")
  }

  get title() {
    return this.element.dataset.bridgeNavbarTitle || document.title
  }
}