import React from "react"
import ReactDOM from "react-dom/client"
import App from "./App"
import { nuiScale } from "./lib/layout"
import "./styles/globals.css"

const scaleNui = () => {
  const root = document.getElementById("root")!
  const scale = nuiScale(window.innerWidth, window.innerHeight)
  root.style.width = `${window.innerWidth / scale}px`
  root.style.height = `${window.innerHeight / scale}px`
  root.style.transform = `scale(${scale})`
  root.style.transformOrigin = "top left"
}

scaleNui()
window.addEventListener("resize", scaleNui)

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
