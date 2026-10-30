import {
  Asterisk,
  Globe2,
  Info,
  MessageSquare,
  Radio,
  Shield,
  Terminal,
} from "lucide-react"
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react"
import {
  completeArgument,
  completeCommand,
  filterCommands,
  limitCharacters,
  normalizeCommandName,
  parseCommand,
  renderCompatibilityTemplate,
} from "./lib/chat"
import { fetchNui, isNui, useNuiEvent } from "./lib/nui"
import type {
  ChatConfig,
  ChatInit,
  ChatMessage,
  CommandSuggestion,
  MessageType,
  ValueSuggestion,
} from "./lib/types"

const DEFAULT_CONFIG: ChatConfig = {
  maxMessageLength: 400,
  messageLimit: 200,
  historyLimit: 50,
  fadeTimeout: 8000,
  suggestionLimit: 8,
  suggestionResultLimit: 20,
  suggestionDebounce: 125,
}

const DEFAULT_TEMPLATES: Record<string, string> = {
  default: "<strong>{0}</strong>: {1}",
  defaultAlt: "{0}",
  print: "<code>{0}</code>",
}

const TYPE_ICONS = {
  message: MessageSquare,
  action: Asterisk,
  globe: Globe2,
  radio: Radio,
  shield: Shield,
  info: Info,
}

function MessageRow({ message, templates }: { message: ChatMessage; templates: Record<string, string> }) {
  const messageType = message.messageType
  const Icon = TYPE_ICONS[messageType?.icon ?? "message"] ?? MessageSquare

  if (message.message != null && message.template == null && message.templateId == null) {
    const action = message.type === "me"
    const builtInClass = action ? "type-me" : message.type === "ooc" ? "type-ooc" : message.type === "say" ? "type-say" : ""
    return (
      <div className={`message-row ${builtInClass}`} style={messageType?.color ? { borderLeftColor: messageType.color } : undefined}>
        <div className="message-icon"><Icon aria-hidden="true" size={15} /></div>
        <div className="message-copy">
          <div className="message-meta">
            <span className="message-type">{messageType?.label ?? "Chat"}</span>
            {!action && <span className="message-author">{message.author}</span>}
          </div>
          <div className={action ? "message-text action" : "message-text"}>
            {action ? `* ${message.author} ${message.message}` : message.message}
          </div>
        </div>
      </div>
    )
  }

  const args = Array.isArray(message.args) ? message.args : []
  const templateId = message.templateId ?? (args.length <= 1 ? "defaultAlt" : "default")
  const fallbackTemplate = templates[templateId] ?? DEFAULT_TEMPLATES.defaultAlt
  const template = (message.template ?? fallbackTemplate).replace(/@default/g, fallbackTemplate)
  const html = renderCompatibilityTemplate(template, args, message.params)
  return (
    <div className="message-row compatibility">
      <div className="message-icon"><Info aria-hidden="true" size={15} /></div>
      <div className="message-text" dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  )
}

export default function App() {
  const [config, setConfig] = useState(DEFAULT_CONFIG)
  const [open, setOpen] = useState(!isNui)
  const [feedVisible, setFeedVisible] = useState(!isNui)
  const [value, setValue] = useState("")
  const [messages, setMessages] = useState<ChatMessage[]>(isNui ? [] : [{
    id: "preview", type: "say", author: "Alex Mercer", message: "This is the kora_lib chat preview.",
    messageType: { name: "say", label: "Local", icon: "message" },
  }])
  const [history, setHistory] = useState<string[]>([])
  const [historyIndex, setHistoryIndex] = useState(-1)
  const [suggestions, setSuggestions] = useState<Record<string, CommandSuggestion>>({})
  const [types, setTypes] = useState<Record<string, MessageType>>({})
  const [templates, setTemplates] = useState(DEFAULT_TEMPLATES)
  const [dynamicValues, setDynamicValues] = useState<ValueSuggestion[]>([])
  const [loadingValues, setLoadingValues] = useState(false)
  const [selectedIndex, setSelectedIndex] = useState(0)
  const [inputOffset, setInputOffset] = useState({ x: 0, y: 0 })
  const [inputScale, setInputScale] = useState(1)
  const [suggestionsAboveInput, setSuggestionsAboveInput] = useState(false)
  const [feedMaxHeight, setFeedMaxHeight] = useState<number>()
  const inputRef = useRef<HTMLInputElement>(null)
  const inputRowRef = useRef<HTMLDivElement>(null)
  const feedRef = useRef<HTMLDivElement>(null)
  const composerRef = useRef<HTMLElement>(null)
  const configuredFeedMaxHeight = useRef<number>()
  const suggestionPanelRef = useRef<HTMLDivElement>(null)
  const fadeTimer = useRef<number>()
  const requestGeneration = useRef(0)

  const suggestionList = useMemo(() => Object.values(suggestions), [suggestions])
  const commandMatches = useMemo(
    () => filterCommands(value, suggestionList, config.suggestionLimit),
    [config.suggestionLimit, suggestionList, value],
  )
  const exactSuggestion = useMemo(() => {
    const command = value.slice(1).split(/\s/, 1)[0]?.toLowerCase()
    return suggestionList.find((item) => normalizeCommandName(item.name).slice(1).toLowerCase() === command)
  }, [suggestionList, value])
  const parsed = useMemo(() => parseCommand(value, exactSuggestion), [exactSuggestion, value])
  const completions = parsed?.exact ? dynamicValues : commandMatches
  const visibleCommands = parsed?.exact && exactSuggestion ? [exactSuggestion] : commandMatches

  const scheduleFade = useCallback((delay = config.fadeTimeout) => {
    if (fadeTimer.current) window.clearTimeout(fadeTimer.current)
    setFeedVisible(true)
    fadeTimer.current = window.setTimeout(() => setFeedVisible(false), delay)
  }, [config.fadeTimeout])

  const pushMessage = useCallback((message: ChatMessage) => {
    const enriched = { ...message, id: message.id ?? `${Date.now()}:${Math.random()}` }
    setMessages((current) => [...current, enriched].slice(-config.messageLimit))
    scheduleFade()
  }, [config.messageLimit, scheduleFade])

  const upsertSuggestion = useCallback((suggestion: Partial<CommandSuggestion>) => {
    if (typeof suggestion.name !== "string") return
    const name = normalizeCommandName(suggestion.name)
    const key = name.toLowerCase()
    setSuggestions((current) => {
      const existing = current[key]
      const incoming: CommandSuggestion = {
        name,
        help: typeof suggestion.help === "string" ? suggestion.help : "",
        params: Array.isArray(suggestion.params) ? suggestion.params : [],
      }
      if (existing && incoming.help === "" && incoming.params.length === 0) return current
      return { ...current, [key]: incoming }
    })
  }, [])

  useNuiEvent<ChatInit>("qbchat:init", ({ config: incoming }) => {
    if (incoming) setConfig((current) => ({ ...current, ...incoming }))
  })
  useNuiEvent<{ x?: unknown; y?: unknown; scale?: unknown }>("qbchat:inputOffset", (incoming) => {
    const x = typeof incoming?.x === "number" && Number.isFinite(incoming.x) ? incoming.x : 0
    const y = typeof incoming?.y === "number" && Number.isFinite(incoming.y) ? incoming.y : 0
    const scale = typeof incoming?.scale === "number" && Number.isFinite(incoming.scale) ? incoming.scale : 1
    setInputOffset({ x: Math.max(-0.95, Math.min(0.95, x)), y: Math.max(-0.95, Math.min(0.95, y)) })
    setInputScale(Math.max(0.75, Math.min(1.5, scale)))
  })
  useNuiEvent<ChatMessage>("qbchat:message", pushMessage)
  useNuiEvent<Record<string, never>>("qbchat:open", () => {
    setOpen(true)
    setFeedVisible(true)
    setHistoryIndex(-1)
  })
  useNuiEvent<Record<string, never>>("qbchat:close", () => {
    setOpen(false)
    setValue("")
    setDynamicValues([])
    scheduleFade()
  })
  useNuiEvent<Record<string, never>>("qbchat:clear", () => {
    setMessages([])
    setHistory([])
    setHistoryIndex(-1)
  })
  useNuiEvent<CommandSuggestion>("qbchat:suggestionAdd", upsertSuggestion)
  useNuiEvent<CommandSuggestion[]>("qbchat:suggestions", (items) => {
    if (!Array.isArray(items)) return
    setSuggestions((current) => {
      const native = new Map<string, CommandSuggestion>()
      items.forEach((item) => {
        if (typeof item.name !== "string") return
        const name = normalizeCommandName(item.name)
        native.set(name.toLowerCase(), { name, help: "", params: [] })
      })

      const next: Record<string, CommandSuggestion> = {}
      for (const [key, suggestion] of Object.entries(current)) {
        const detailed = suggestion.help !== "" || suggestion.params.length > 0
        if (detailed || native.has(key)) next[key] = suggestion
      }
      for (const [key, suggestion] of native) {
        if (!next[key]) next[key] = suggestion
      }
      return next
    })
  })
  useNuiEvent<string>("qbchat:suggestionRemove", (name) => {
    setSuggestions((current) => {
      const next = { ...current }
      delete next[normalizeCommandName(name).toLowerCase()]
      return next
    })
  })
  useNuiEvent<{ id?: string; template?: string }>("qbchat:templateAdd", ({ id, template }) => {
    if (id && typeof template === "string") setTemplates((current) => ({ ...current, [id]: template }))
  })
  useNuiEvent<MessageType>("qbchat:typeAdd", (messageType) => {
    if (messageType?.name) setTypes((current) => ({ ...current, [messageType.name!]: messageType }))
  })
  useNuiEvent<MessageType[]>("qbchat:types", (items) => {
    const next: Record<string, MessageType> = {}
    items?.forEach((item) => { if (item.name) next[item.name] = item })
    setTypes(next)
  })
  useNuiEvent<string>("qbchat:typeRemove", (name) => {
    setTypes((current) => { const next = { ...current }; delete next[name]; return next })
  })

  useEffect(() => {
    void fetchNui("qbchat:ready")
    return () => { if (fadeTimer.current) window.clearTimeout(fadeTimer.current) }
  }, [])

  useEffect(() => {
    if (open) window.setTimeout(() => inputRef.current?.focus(), 0)
  }, [open])

  useEffect(() => {
    feedRef.current?.scrollTo({ top: feedRef.current.scrollHeight })
  }, [messages, open])

  useLayoutEffect(() => {
    const feed = feedRef.current
    const composer = composerRef.current
    if (!open || !feed || !composer) {
      configuredFeedMaxHeight.current = undefined
      setFeedMaxHeight(undefined)
      return
    }

    const updateFeedHeight = () => {
      const feedBounds = feed.getBoundingClientRect()
      const composerBounds = composer.getBoundingClientRect()
      if (feed.offsetWidth === 0 || feedBounds.width === 0 || composerBounds.height === 0) return

      const nuiScale = feedBounds.width / feed.offsetWidth
      configuredFeedMaxHeight.current ??= Number.parseFloat(window.getComputedStyle(feed).maxHeight)
      const configuredLimit = configuredFeedMaxHeight.current
      if (!Number.isFinite(configuredLimit)) return
      const availableHeight = (composerBounds.top - feedBounds.top - 12) / nuiScale
      setFeedMaxHeight(Math.max(0, Math.min(configuredLimit, availableHeight)))
    }

    updateFeedHeight()
    window.addEventListener("resize", updateFeedHeight)
    const observer = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(updateFeedHeight)
    observer?.observe(feed)
    observer?.observe(composer)
    return () => {
      window.removeEventListener("resize", updateFeedHeight)
      observer?.disconnect()
    }
  }, [inputOffset.y, inputScale, messages.length, open])

  useEffect(() => {
    setSelectedIndex(0)
    setDynamicValues([])
    requestGeneration.current += 1
    const generation = requestGeneration.current

    if (!parsed?.exact || !parsed.param?.hasSuggestions || parsed.argumentIndex < 1) {
      setLoadingValues(false)
      return
    }

    setLoadingValues(true)
    const timer = window.setTimeout(async () => {
      try {
        const result = await fetchNui<ValueSuggestion[]>("qbchat:suggest", {
          command: parsed.command,
          argumentIndex: parsed.argumentIndex,
          query: parsed.query,
          args: parsed.args,
        })
        if (requestGeneration.current === generation) {
          setDynamicValues(Array.isArray(result) ? result.slice(0, config.suggestionResultLimit) : [])
        }
      } catch {
        if (requestGeneration.current === generation) setDynamicValues([])
      } finally {
        if (requestGeneration.current === generation) setLoadingValues(false)
      }
    }, config.suggestionDebounce)
    return () => window.clearTimeout(timer)
  }, [config.suggestionDebounce, config.suggestionResultLimit, parsed])

  const submit = useCallback((cancelled = false) => {
    const message = limitCharacters(value.trim(), config.maxMessageLength)
    if (!cancelled && message !== "") {
      setHistory((current) => [message, ...current.filter((entry) => entry !== message)].slice(0, config.historyLimit))
    }
    setOpen(false)
    setValue("")
    setHistoryIndex(-1)
    setDynamicValues([])
    scheduleFade()
    void fetchNui("qbchat:submit", { cancelled, message })
  }, [config.historyLimit, scheduleFade, value])

  const completeSuggestion = useCallback((completion: CommandSuggestion | ValueSuggestion) => {
    setValue(limitCharacters(
      "value" in completion
        ? completeArgument(value, completion.value)
        : completeCommand(completion.name),
      config.maxMessageLength,
    ))
    inputRef.current?.focus()
  }, [config.maxMessageLength, value])

  // The input normally handles Escape, but focus can be handed to another
  // element while the composer remains visible. Keep a document-level escape
  // hatch so the player can always dismiss chat without reopening the UI.
  useEffect(() => {
    const dismissWithEscape = (event: KeyboardEvent) => {
      if (!open || event.key !== "Escape" || event.target === inputRef.current) return
      event.preventDefault()
      submit(true)
    }
    window.addEventListener("keydown", dismissWithEscape)
    return () => window.removeEventListener("keydown", dismissWithEscape)
  }, [open, submit])

  const handleKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Escape") {
      event.preventDefault()
      submit(true)
      return
    }
    if (event.key === "Enter") {
      event.preventDefault()
      submit(false)
      return
    }
    if (event.key === "Tab") {
      event.preventDefault()
      const completion = completions[selectedIndex]
      if (!completion) return
      completeSuggestion(completion)
      return
    }
    if (event.key === "ArrowUp" || event.key === "ArrowDown") {
      event.preventDefault()
      const direction = event.key === "ArrowUp" ? -1 : 1
      if (completions.length > 0) {
        setSelectedIndex((current) => (current + direction + completions.length) % completions.length)
        return
      }
      if (history.length === 0) return
      const next = event.key === "ArrowUp"
        ? Math.min(historyIndex + 1, history.length - 1)
        : Math.max(historyIndex - 1, -1)
      setHistoryIndex(next)
      setValue(next === -1 ? "" : limitCharacters(history[next], config.maxMessageLength))
    }
  }

  const showSuggestionPanel = open && value.startsWith("/") && (
    visibleCommands.length > 0 || exactSuggestion != null || loadingValues
  )

  useLayoutEffect(() => {
    const panel = suggestionPanelRef.current
    const inputRow = inputRowRef.current
    if (!panel || !inputRow || !showSuggestionPanel) {
      setSuggestionsAboveInput(false)
      return
    }

    const updatePosition = () => {
      const inputBottom = inputRow.getBoundingClientRect().bottom
      setSuggestionsAboveInput(inputBottom + 6 + panel.offsetHeight > window.innerHeight)
    }

    updatePosition()
    window.addEventListener("resize", updatePosition)
    const observer = typeof ResizeObserver === "undefined" ? null : new ResizeObserver(updatePosition)
    observer?.observe(panel)
    return () => {
      window.removeEventListener("resize", updatePosition)
      observer?.disconnect()
    }
  }, [dynamicValues.length, loadingValues, showSuggestionPanel, visibleCommands.length])

  return (
    <main className="chat-shell" data-types={Object.keys(types).length}>
      <section
        aria-live="polite"
        className={`message-feed ${feedVisible || open ? "visible" : "hidden"}`}
        ref={feedRef}
        style={feedMaxHeight === undefined ? undefined : { maxHeight: `${feedMaxHeight}px` }}
      >
        {messages.map((message) => <MessageRow key={message.id} message={message} templates={templates} />)}
      </section>

      {open && (
        <section
          className="composer"
          aria-label="Chat input"
          ref={composerRef}
          style={{ transform: `translate(${inputOffset.x * 100}vw, ${inputOffset.y * 100}vh) scale(${inputScale})`, transformOrigin: "top left" }}
        >
          <div className="input-row" ref={inputRowRef}>
            <Terminal aria-hidden="true" size={16} />
            <input
              ref={inputRef}
              aria-label="Chat message"
              autoComplete="off"
              onChange={(event) => setValue(limitCharacters(event.target.value, config.maxMessageLength))}
              onKeyDown={handleKeyDown}
              placeholder="Type a message or /command"
              spellCheck={false}
              value={value}
            />
            <kbd>Esc</kbd>
          </div>

          {showSuggestionPanel && (
            <div
              className={`suggestion-panel ${suggestionsAboveInput ? "above-input" : ""}`}
              ref={suggestionPanelRef}
              role="listbox"
              aria-label="Command suggestions"
            >
              {visibleCommands.map((suggestion, index) => {
                const activeArgument = parsed?.exact ? parsed.argumentIndex : 0
                return (
                  <div
                    aria-selected={completions === commandMatches && selectedIndex === index}
                  className={`suggestion-row ${completions === commandMatches && selectedIndex === index ? "selected" : ""}`}
                  key={suggestion.name}
                  onClick={() => completeSuggestion(suggestion)}
                  onMouseDown={(event) => event.preventDefault()}
                  role="option"
                  >
                    <div className="signature">
                      <span className="command-name">{normalizeCommandName(suggestion.name)}</span>
                      {suggestion.params.map((param, paramIndex) => (
                        <span className={activeArgument === paramIndex + 1 ? "argument active" : "argument"} key={`${param.name}:${paramIndex}`}>
                          [{param.name ?? `arg${paramIndex + 1}`}]
                        </span>
                      ))}
                    </div>
                    <div className="suggestion-help">
                      {activeArgument > 0
                        ? suggestion.params[activeArgument - 1]?.help || suggestion.help
                        : suggestion.help}
                    </div>
                  </div>
                )
              })}

              {loadingValues && <div className="suggestion-state">Loading argument values…</div>}
              {!loadingValues && parsed?.param?.hasSuggestions && dynamicValues.length === 0 && (
                <div className="suggestion-state">No matching values</div>
              )}
              {dynamicValues.map((suggestion, index) => (
                <div
                  aria-selected={selectedIndex === index}
                  className={`suggestion-row value ${selectedIndex === index ? "selected" : ""}`}
                  key={suggestion.value}
                  onClick={() => completeSuggestion(suggestion)}
                  onMouseDown={(event) => event.preventDefault()}
                  role="option"
                >
                  <div className="signature">
                    <span className="command-name">{suggestion.label ?? suggestion.value}</span>
                    {suggestion.label && <span className="argument">{suggestion.value}</span>}
                  </div>
                  {suggestion.help && <div className="suggestion-help">{suggestion.help}</div>}
                </div>
              ))}
              <div className="suggestion-footer"><kbd>↑↓</kbd> navigate <kbd>Tab</kbd> complete <kbd>Enter</kbd> send</div>
            </div>
          )}
        </section>
      )}
    </main>
  )
}
