export interface ChatConfig {
  maxMessageLength: number
  messageLimit: number
  historyLimit: number
  fadeTimeout: number
  suggestionLimit: number
  suggestionResultLimit: number
  suggestionDebounce: number
}

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
}

export interface ChatInit {
  config?: Partial<ChatConfig>
  theme?: Record<string, string>
}
