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
import { chatGeometry, HISTORY_GAP, INPUT_HEIGHT, nuiScale } from "./lib/layout"
import { fetchNui, isNui, useNuiEvent } from "./lib/nui"
import type {
  ChatConfig,
  ChatInit,
  ChatMessage,
  ChatPrefs,
  CommandSuggestion,
  MessageType,
  ValueSuggestion,
} from "./lib/types"

const DEFAULT_CONFIG: ChatConfig = {
  maxMessageLength: 400,
  messageLimit: 200,
  historyLimit: 50,
  fadeTimeout: 8000,
  fadeMode: "message",
  fadeDuration: 600,
  backgroundOpacity: 94,
  suggestionLimit: 8,
  suggestionResultLimit: 20,
  suggestionDebounce: 125,
  showActionAuthor: true,
  showActionAsterisk: false,
  historyHeight: 32,
  historyPlacement: "auto",
  position: { anchor: "top", x: 16, y: 40 },
  layoutOrigin: { x: 16, y: 16 },
}

const HISTORY_HEIGHT_RANGE = { min: 10, max: 90 }

/** Shown in the feed while /ui is open and there is nothing to look at yet. */
const PREVIEW_MESSAGES: ChatMessage[] = [
  { id: "ui-preview-1", type: "say", author: "Alex Mercer", message: "This is how chat messages look.", messageType: { name: "say", label: "Local", icon: "message" } },
  { id: "ui-preview-2", type: "me", author: "Alex Mercer", message: "adjusts the chat.", messageType: { name: "me", label: "Action", icon: "action" } },
]

function clampNumber(value: unknown, min: number, max: number, fallback: number) {
  return typeof value === "number" && Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback
}

function defaultPrefs(config: ChatConfig): ChatPrefs {
  return {
    fadeSeconds: clampNumber(Math.round(config.fadeTimeout / 1000), 0, 60, 8),
    opacity: clampNumber(config.backgroundOpacity, 20, 100, 94),
    feedWhenClosed: true,
  }
}

/**
 * Height of the fixed history region in percent of the screen height.
 * historyHeight wins; the older openHistoryHeight is honoured so existing
 * config copies keep their size.
 */
function resolveHistoryHeight(config: ChatConfig) {
  const configured = [config.historyHeight, config.openHistoryHeight, DEFAULT_CONFIG.historyHeight]
    .find((value): value is number => typeof value === "number" && Number.isFinite(value))!
  return Math.max(HISTORY_HEIGHT_RANGE.min, Math.min(HISTORY_HEIGHT_RANGE.max, configured))
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

function MessageRow({ message, templates, showActionAuthor = true, showActionAsterisk = false, faded = false }: {
  message: ChatMessage
  templates: Record<string, string>
  showActionAuthor?: boolean
  showActionAsterisk?: boolean
  faded?: boolean
}) {
  const fadeClass = faded ? " faded" : ""
  const messageType = message.messageType
  const Icon = TYPE_ICONS[messageType?.icon ?? "message"] ?? MessageSquare

  if (message.message != null && message.template == null && message.templateId == null) {
    const action = message.type === "me"
    const actionAuthor = showActionAuthor && message.author ? message.author : null
    const builtInClass = action ? "type-me" : message.type === "ooc" ? "type-ooc" : message.type === "say" ? "type-say" : ""
    return (
      <div className={`message-row ${builtInClass}${fadeClass}`} style={messageType?.color ? { borderLeftColor: messageType.color } : undefined}>
        <div className="message-icon"><Icon aria-hidden="true" size={15} /></div>
        <div className="message-copy">
          <div className="message-meta">
            <span className="message-type">{messageType?.label ?? "Chat"}</span>
            {!action && <span className="message-author">{message.author}</span>}
          </div>
          <div className={action ? "message-text action" : "message-text"}>
            {action ? (
              <>
                {showActionAsterisk && "* "}
                {actionAuthor && <><span className="action-author">{actionAuthor}</span>{" "}</>}
                {message.message}
              </>
            ) : message.message}
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
    <div className={`message-row compatibility${fadeClass}`}>
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
  const [windowSize, setWindowSize] = useState({ width: window.innerWidth, height: window.innerHeight })
  // Per-player preferences from the /ui editor (kora_hud), null until Lua
  // sends them; the server config is the default meanwhile.
  const [prefsState, setPrefs] = useState<ChatPrefs | null>(null)
  const [editing, setEditing] = useState(false)
  // Clock for per-message fading. Only advanced by the one timer below, at the
  // moment the next message is due to fade -- never on an interval.
  const [now, setNow] = useState(() => Date.now())
  const inputRef = useRef<HTMLInputElement>(null)
  const inputRowRef = useRef<HTMLDivElement>(null)
  const feedRef = useRef<HTMLDivElement>(null)
  const composerRef = useRef<HTMLElement>(null)
  const suggestionPanelRef = useRef<HTMLDivElement>(null)
  const fadeTimer = useRef<number>()
  const requestGeneration = useRef(0)

  // The root is scaled by nuiScale (main.tsx), exactly like kora_hud's, so the
  // block is laid out in that root pixel space rather than in vw/vh: a vh
  // inside a scaled root covers more than its share of the real screen.
  const rootScale = nuiScale(windowSize.width, windowSize.height)
  const inputHeight = windowSize.width <= 640 ? 44 : INPUT_HEIGHT
  // .chat-shell is min(480px, 38vw); vw ignores the root's transform, so this
  // is already in root pixels.
  const inputWidth = Math.min(480, 0.38 * windowSize.width)
  const geometry = useMemo(() => chatGeometry({
    viewport: { width: windowSize.width / rootScale, height: windowSize.height / rootScale },
    config,
    historyPercent: resolveHistoryHeight(config),
    layout: { x: inputOffset.x, y: inputOffset.y, scale: inputScale },
    inputHeight,
    inputWidth,
  }), [config, inputHeight, inputOffset.x, inputOffset.y, inputScale, inputWidth, rootScale, windowSize.height, windowSize.width])

  const prefs = prefsState ?? defaultPrefs(config)
  const perMessageFade = config.fadeMode !== "feed"
  const fadeMs = prefs.fadeSeconds * 1000
  const fadeDuration = clampNumber(config.fadeDuration, 0, 5000, 600)

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

  // Whole-feed fade ('feed' mode, the old behaviour). In 'message' mode the
  // feed itself stays visible and each row fades on its own (see below).
  const scheduleFade = useCallback((delay = fadeMs) => {
    if (fadeTimer.current) window.clearTimeout(fadeTimer.current)
    setFeedVisible(true)
    if (!perMessageFade && delay > 0) {
      fadeTimer.current = window.setTimeout(() => setFeedVisible(false), delay)
    }
  }, [fadeMs, perMessageFade])

  const pushMessage = useCallback((message: ChatMessage) => {
    const receivedAt = Date.now()
    const enriched = { ...message, id: message.id ?? `${receivedAt}:${Math.random()}`, receivedAt }
    setMessages((current) => [...current, enriched].slice(-config.messageLimit))
    scheduleFade()
  }, [config.messageLimit, scheduleFade])

  // One timeout for the next message due to fade; re-armed when messages
  // arrive or one fades. Nothing runs while chat is open, in the editor, with
  // fading off, or when every message has already faded.
  useEffect(() => {
    if (!perMessageFade || open || editing || fadeMs <= 0) return
    const current = Date.now()
    let next = Infinity
    for (const message of messages) {
      const due = (message.receivedAt ?? 0) + fadeMs
      if (due > current && due < next) next = due
    }
    if (next === Infinity) return
    const timer = window.setTimeout(() => setNow(Date.now()), next - current + 20)
    return () => window.clearTimeout(timer)
  }, [editing, fadeMs, messages, now, open, perMessageFade])

  // Closing chat (or the editor) re-evaluates which messages are faded now.
  useEffect(() => {
    if (!open && !editing) setNow(Date.now())
  }, [editing, open])

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
  useNuiEvent<Partial<ChatPrefs>>("qbchat:prefs", (incoming) => {
    if (!incoming || typeof incoming !== "object") return
    setPrefs({
      fadeSeconds: clampNumber(incoming.fadeSeconds, 0, 60, defaultPrefs(config).fadeSeconds),
      opacity: clampNumber(incoming.opacity, 20, 100, defaultPrefs(config).opacity),
      feedWhenClosed: incoming.feedWhenClosed !== false,
    })
  })
  useNuiEvent<boolean>("qbchat:editing", (value) => {
    setEditing(value === true)
  })
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
  useNuiEvent<Record<string, never>>("qbchat:clearMessages", () => {
    setMessages([])
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
    const onResize = () => setWindowSize({ width: window.innerWidth, height: window.innerHeight })
    window.addEventListener("resize", onResize)
    return () => window.removeEventListener("resize", onResize)
  }, [])

  // Tell kora_hud's /ui editor where the input box really is at this
  // resolution: the zero point of a saved offset (layoutOrigin) and where the
  // chat sits when nothing is saved. Debounced; only sent when it changed.
  const lastGeometry = useRef("")
  useEffect(() => {
    if (!isNui) return
    const timer = window.setTimeout(() => {
      const width = windowSize.width / rootScale
      const height = windowSize.height / rootScale
      const originX = Number.isFinite(config.layoutOrigin?.x) ? Number(config.layoutOrigin?.x) : 16
      const originY = Number.isFinite(config.layoutOrigin?.y) ? Number(config.layoutOrigin?.y) : 16
      const unplaced = chatGeometry({
        viewport: { width, height },
        config,
        historyPercent: resolveHistoryHeight(config),
        layout: { x: 0, y: 0, scale: 1 },
        inputHeight,
        inputWidth,
      })
      const payload = {
        rect: { x: originX / width, y: originY / height, w: inputWidth / width, h: inputHeight / height },
        defaultOffset: { x: (unplaced.left - originX) / width, y: (unplaced.top - originY) / height },
      }
      const key = JSON.stringify(payload)
      if (key === lastGeometry.current) return
      lastGeometry.current = key
      void fetchNui("qbchat:geometry", payload).catch(() => { lastGeometry.current = "" })
    }, 300)
    return () => window.clearTimeout(timer)
  }, [config, inputHeight, inputWidth, rootScale, windowSize.height, windowSize.width])

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
    if (event.key === "PageUp" || event.key === "PageDown") {
      event.preventDefault()
      const feed = feedRef.current
      if (feed) feed.scrollBy({ top: (event.key === "PageUp" ? -1 : 1) * feed.clientHeight * 0.9 })
      return
    }
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
    <main
      className="chat-shell"
      data-types={Object.keys(types).length}
      // The shell box IS the input box: its top-left is the /hudlayout "Chat
      // input" spot, and the history hangs off it out of flow, so neither the
      // messages nor opening/closing the input can move it.
      style={{
        top: `${geometry.top}px`,
        left: `${geometry.left}px`,
        transform: `scale(${geometry.scale})`,
        transformOrigin: "top left",
        ["--chat-surface-alpha" as string]: String(prefs.opacity / 100),
        ["--chat-fade-duration" as string]: `${fadeDuration}ms`,
      }}
    >
      <section
        aria-live="polite"
        className={`message-feed ${geometry.historyPlacement} ${open || editing || (prefs.feedWhenClosed && (perMessageFade || feedVisible)) ? "visible" : "hidden"} ${open ? "open" : ""}`}
        ref={feedRef}
        style={{
          height: `${geometry.historyHeight}px`,
          [geometry.historyPlacement === "above" ? "bottom" : "top"]: `calc(100% + ${HISTORY_GAP}px)`,
        }}
      >
        {(editing && messages.length === 0 ? PREVIEW_MESSAGES : messages).map((message) => (
          <MessageRow
            key={message.id}
            message={message}
            showActionAuthor={config.showActionAuthor !== false}
            showActionAsterisk={config.showActionAsterisk === true}
            templates={templates}
            faded={perMessageFade && !open && !editing && fadeMs > 0 && now - (message.receivedAt ?? 0) >= fadeMs}
          />
        ))}
      </section>

      {!open && editing && (
        // Static stand-in for the composer while /ui is open, so the player
        // can see the box they are moving. Never focusable.
        <div className="composer composer-preview" aria-hidden="true">
          <div className="input-row">
            <Terminal aria-hidden="true" size={16} />
            <span className="input-placeholder">Type a message or /command</span>
            <kbd>Esc</kbd>
          </div>
        </div>
      )}
      {!open && !editing && <div className="composer-spacer" aria-hidden="true" />}

      {open && (
        <section
          className="composer"
          aria-label="Chat input"
          ref={composerRef}
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
