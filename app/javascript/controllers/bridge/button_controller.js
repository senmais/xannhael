import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "button"

  connect() {
    super.connect()
    this.send("right", { title: this.title })
  }

  receive(message) {
    if (message.event === "right" || message.event === "connect") {
      this.bridgeElement.click()
    }
  }

  get title() {
    return this.bridgeElement.title
  }
}
