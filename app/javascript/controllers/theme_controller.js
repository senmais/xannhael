import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const saved = localStorage.getItem("theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    this.apply(saved ? saved === "dark" : prefersDark)
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    this.apply(!isDark)
    localStorage.setItem("theme", isDark ? "light" : "dark")
  }

  apply(dark) {
    document.documentElement.classList.toggle("dark", dark)
  }
}