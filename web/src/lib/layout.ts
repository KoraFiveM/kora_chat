import type { ChatConfig, HistoryPlacement } from "./types"

export const INPUT_HEIGHT = 48
export const HISTORY_GAP = 6
export const SCREEN_MARGIN = 8
export const DEFAULT_LAYOUT_ORIGIN = { x: 16, y: 16 }

export interface InputLayout {
  x: number
  y: number
  scale: number
}

export interface ChatGeometry {
  /** Top-left of the input box in root (unscaled NUI) pixels. */
  left: number
  top: number
  scale: number
  /** History region height in pixels before the layout scale is applied. */
  historyHeight: number
  historyPlacement: Exclude<HistoryPlacement, "auto">
}

/** Same factor as main.tsx and kora_hud's main.tsx, so both NUIs share one coordinate space. */
export function nuiScale(width: number, height: number) {
  return Math.min(2, Math.max(0.5, Math.min(width / 1920, height / 1080)))
}

function finite(value: unknown, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback
}

/**
 * Where the chat block goes, from config, the saved /hudlayout placement and
 * the viewport only. Nothing here depends on the messages, so the block can
 * never move or resize as they arrive.
 *
 * A /hudlayout placement is the "Chat input" proxy kora_hud draws: its saved
 * offset is a viewport fraction from layoutOrigin, converted in the same root
 * pixel space kora_hud uses, so the input lands exactly on the proxy at every
 * resolution. The history sits directly above the input, or below it when
 * there is not enough room above (historyPlacement "auto").
 *
 * Without a placement (offset 0,0 and scale 1, i.e. never moved or reset),
 * Config.chat.position is used: anchor "top" puts the top of the history at y,
 * "bottom" puts the bottom of the input y above the bottom edge.
 */
export function chatGeometry(options: {
  viewport: { width: number; height: number }
  config: Pick<ChatConfig, "position" | "layoutOrigin" | "historyPlacement">
  historyPercent: number
  layout: InputLayout
  inputHeight?: number
}): ChatGeometry {
  const { width, height } = options.viewport
  const { config, layout } = options
  const inputHeight = options.inputHeight ?? INPUT_HEIGHT
  const placed = layout.x !== 0 || layout.y !== 0 || layout.scale !== 1
  const scale = placed ? layout.scale : 1
  const desired = (options.historyPercent / 100) * height / scale

  let left: number
  let top: number
  if (placed) {
    left = finite(config.layoutOrigin?.x, DEFAULT_LAYOUT_ORIGIN.x) + layout.x * width
    top = finite(config.layoutOrigin?.y, DEFAULT_LAYOUT_ORIGIN.y) + layout.y * height
  } else {
    const edge = finite(config.position?.y, 40)
    left = finite(config.position?.x, 16)
    top = config.position?.anchor === "bottom"
      ? height - edge - inputHeight
      : edge + Math.min(desired, height - edge - inputHeight - HISTORY_GAP - SCREEN_MARGIN) + HISTORY_GAP
  }
  // Only ever pulls an off-screen input back; any on-screen spot is kept exactly.
  top = Math.max(0, Math.min(height - inputHeight * scale, top))

  const roomAbove = (top - SCREEN_MARGIN) / scale - HISTORY_GAP
  const roomBelow = (height - SCREEN_MARGIN - top) / scale - inputHeight - HISTORY_GAP
  const requested = config.historyPlacement
  const historyPlacement = requested === "above" || requested === "below"
    ? requested
    : roomAbove >= desired ? "above" : roomBelow >= desired ? "below" : roomAbove >= roomBelow ? "above" : "below"
  const room = historyPlacement === "above" ? roomAbove : roomBelow

  return {
    left,
    top,
    scale,
    historyHeight: Math.max(0, Math.min(desired, room)),
    historyPlacement,
  }
}
