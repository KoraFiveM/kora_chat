import { describe, expect, it } from "vitest"
import { chatGeometry, HISTORY_GAP, INPUT_HEIGHT, nuiScale } from "./layout"
import type { ChatConfig } from "./types"

const SCREENS = [
  { width: 1920, height: 1080 },
  { width: 2560, height: 1440 },
  { width: 3440, height: 1440 },
  { width: 1280, height: 720 },
]

const CONFIG: Pick<ChatConfig, "position" | "layoutOrigin" | "historyPlacement"> = {
  position: { anchor: "top", x: 16, y: 40 },
  layoutOrigin: { x: 16, y: 16 },
  historyPlacement: "auto",
}

function geometryOnScreen(screen: { width: number; height: number }, layout: { x: number; y: number; scale: number }, config = CONFIG) {
  const s = nuiScale(screen.width, screen.height)
  const geometry = chatGeometry({
    viewport: { width: screen.width / s, height: screen.height / s },
    config,
    historyPercent: 32,
    layout,
  })
  return { s, geometry }
}

/** Where kora_hud draws the "Chat input" proxy: fixed left-4 top-4 plus the offset in its scaled root. */
function proxyTopLeft(screen: { width: number; height: number }, layout: { x: number; y: number }) {
  const s = nuiScale(screen.width, screen.height)
  return { left: s * (16 + layout.x * (screen.width / s)), top: s * (16 + layout.y * (screen.height / s)) }
}

describe("chat geometry", () => {
  it.each(SCREENS)("puts the input exactly on the /hudlayout proxy at $width x $height", (screen) => {
    for (const layout of [
      { x: 0, y: 0.8, scale: 1 },
      { x: 0.3, y: 0.45, scale: 1.25 },
      { x: 0.02, y: 0.05, scale: 0.75 },
      { x: 0.6, y: 0.9, scale: 1.5 },
    ]) {
      const { s, geometry } = geometryOnScreen(screen, layout)
      const proxy = proxyTopLeft(screen, layout)
      expect(s * geometry.left).toBeCloseTo(proxy.left, 6)
      expect(s * geometry.top).toBeCloseTo(proxy.top, 6)
      expect(geometry.scale).toBe(layout.scale)
    }
  })

  it.each(SCREENS)("keeps the history at historyHeight percent of the $width x $height screen", (screen) => {
    const { s, geometry } = geometryOnScreen(screen, { x: 0, y: 0.8, scale: 1.25 })
    expect(geometry.historyPlacement).toBe("above")
    expect(s * geometry.historyHeight * geometry.scale).toBeCloseTo(0.32 * screen.height, 6)
  })

  it("puts the history below the input when it is placed too high for it to fit above", () => {
    const { geometry } = geometryOnScreen(SCREENS[0], { x: 0, y: 0.05, scale: 1 })
    expect(geometry.historyPlacement).toBe("below")
    expect(geometry.historyHeight).toBeCloseTo(0.32 * 1080, 6)
  })

  it("shrinks a forced placement to the room available instead of leaving the screen", () => {
    const { geometry } = geometryOnScreen(SCREENS[0], { x: 0, y: 0.05, scale: 1 }, { ...CONFIG, historyPlacement: "above" })
    expect(geometry.historyPlacement).toBe("above")
    expect(geometry.historyHeight).toBe(16 + 0.05 * 1080 - 8 - HISTORY_GAP)
  })

  it("uses Config.chat.position while there is no /hudlayout placement", () => {
    const top = geometryOnScreen(SCREENS[0], { x: 0, y: 0, scale: 1 }).geometry
    expect(top).toMatchObject({ left: 16, scale: 1, historyPlacement: "above" })
    expect(top.top).toBeCloseTo(40 + 0.32 * 1080 + HISTORY_GAP, 6)

    const bottom = geometryOnScreen(SCREENS[0], { x: 0, y: 0, scale: 1 }, { ...CONFIG, position: { anchor: "bottom", x: 20, y: 120 } }).geometry
    expect(bottom).toMatchObject({ left: 20, top: 1080 - 120 - INPUT_HEIGHT, historyPlacement: "above" })
  })

  it("pulls only an off-screen input back onto the screen", () => {
    const { geometry } = geometryOnScreen(SCREENS[0], { x: 0, y: 0.95, scale: 1.5 })
    expect(geometry.top).toBe(1080 - INPUT_HEIGHT * 1.5)
  })
})
