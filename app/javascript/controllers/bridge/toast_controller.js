import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "toast"

  connect() {
    super.connect()
    const message = this.element.dataset.bridgeToastMessage
    if (!message) return

    this.send("show", { message })
  }
}