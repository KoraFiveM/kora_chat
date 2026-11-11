export interface ChatConfig {
  maxMessageLength: number
  messageLimit: number
  historyLimit: number
  fadeTimeout: number
  /** 'message' fades each message on its own; 'feed' hides the whole feed (old behaviour). */
  fadeMode?: "message" | "feed"
  /** Length of one message's fade-out, in ms. */
  fadeDuration?: number
  /** Default background opacity (20-100) before a player changes it in /ui. */
  backgroundOpacity?: number
  suggestionLimit: number
  suggestionResultLimit: number
  suggestionDebounce: number
  /** Prefix /me action messages with the author name. Defaults to true. */
  showActionAuthor?: boolean
  /** Start /me action messages with "* ". Defaults to false. */
  showActionAsterisk?: boolean
  historyHeight?: number
  /** @deprecated Use historyHeight. */
  openHistoryHeight?: number
  position?: { anchor?: "top" | "bottom"; x?: number; y?: number }
  historyPlacement?: HistoryPlacement
  layoutOrigin?: { x?: number; y?: number }
}

export type HistoryPlacement = "auto" | "above" | "below"

export interface CommandParam {
  name?: string
  help?: string
  hasSuggestions?: boolean
}

export interface CommandSuggestion {
  name: string
  help: string
  params: CommandParam[]
}

export interface ValueSuggestion {
  value: string
  label?: string
  help?: string
}

export interface MessageType {
  name?: string
  label?: string
  icon?: "message" | "action" | "globe" | "radio" | "shield" | "info"
  color?: string
  scope?: "local" | "global"
  overhead?: boolean
}

export interface ChatMessage {
  id?: string
  type?: string
  messageType?: MessageType
  author?: string
  message?: string
  source?: number
  timestamp?: number
  args?: unknown[]
  params?: Record<string, unknown>
  template?: string
  templateId?: string
  color?: number[]
  multiline?: boolean
  /** Set by the page when the message arrived (ms), for per-message fading. */
  receivedAt?: number
}

/** Per-player chat preferences from kora_hud's /ui editor. */
export interface ChatPrefs {
  /** Seconds before a message fades while chat is closed; 0 = never. */
  fadeSeconds: number
  /** Background opacity of rows and the input, 20-100. */
  opacity: number
  /** Show messages at all while the input is closed. */
  feedWhenClosed: boolean
}

export interface ChatInit {
  config?: Partial<ChatConfig>
  theme?: Record<string, string>
}
