import { act, fireEvent, render, screen, waitFor } from "@testing-library/react"
import { beforeEach, describe, expect, it, vi } from "vitest"
import App from "./App"
import css from "./styles/globals.css?raw"

function nui(action: string, data: unknown) {
  window.dispatchEvent(new MessageEvent("message", { data: { action, data } }))
}

describe("chat interactions", () => {
  beforeEach(() => {
    vi.useRealTimers()
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true, json: async () => ({}) })))
  })

  it("opens, filters, and completes a command with Tab", async () => {
    render(<App />)
    nui("qbchat:suggestionAdd", { name: "/giveitem", help: "Give item", params: [{ name: "id" }] })
    nui("qbchat:open", {})
    const input = await screen.findByLabelText("Chat message")
    fireEvent.change(input, { target: { value: "/giv" } })
    await screen.findByText("/giveitem")
    fireEvent.keyDown(input, { key: "Tab" })
    expect(input).toHaveValue("/giveitem ")
  })

  it("completes a command when its suggestion is clicked", async () => {
    render(<App />)
    nui("qbchat:suggestionAdd", { name: "/giveitem", help: "Give item", params: [{ name: "id" }] })
    nui("qbchat:open", {})
    const input = await screen.findByLabelText("Chat message")
    fireEvent.change(input, { target: { value: "/giv" } })
    fireEvent.click(await screen.findByRole("option", { name: /giveitem/i }))
    expect(input).toHaveValue("/giveitem ")
    expect(input).toHaveFocus()
  })

  it("places suggestions above the input when they would overflow the viewport", async () => {
    const bounds = vi.spyOn(HTMLElement.prototype, "getBoundingClientRect").mockImplementation(function (this: HTMLElement) {
      return {
        bottom: this.classList.contains("input-row") ? window.innerHeight - 20 : 0,
      } as DOMRect
    })
    render(<App />)
    nui("qbchat:suggestionAdd", { name: "/giveitem", help: "Give item", params: [] })
    nui("qbchat:open", {})
    const input = await screen.findByLabelText("Chat message")
    fireEvent.change(input, { target: { value: "/giv" } })
    const panel = await screen.findByRole("listbox")
    Object.defineProperty(panel, "offsetHeight", { configurable: true, value: 200 })
    fireEvent(window, new Event("resize"))

    await waitFor(() => expect(panel).toHaveClass("above-input"))
    bounds.mockRestore()
  })

  it("submits history and recalls it with ArrowUp", async () => {
    render(<App />)
    nui("qbchat:open", {})
    let input = await screen.findByLabelText("Chat message")
    fireEvent.change(input, { target: { value: "hello" } })
    fireEvent.keyDown(input, { key: "Enter" })
    await waitFor(() => expect(screen.queryByLabelText("Chat message")).not.toBeInTheDocument())

    nui("qbchat:open", {})
    input = await screen.findByLabelText("Chat message")
    fireEvent.keyDown(input, { key: "ArrowUp" })
    expect(input).toHaveValue("hello")
  })

  it("dismisses an open composer with Escape when the input has lost focus", async () => {
    render(<App />)
    nui("qbchat:open", {})
    await screen.findByLabelText("Chat message")
    fireEvent.keyDown(window, { key: "Escape" })
    await waitFor(() => expect(screen.queryByLabelText("Chat message")).not.toBeInTheDocument())
  })

  it("clears received messages", async () => {
    render(<App />)
    nui("qbchat:message", { id: "one", args: ["System message"] })
    await screen.findByText("System message")
    nui("qbchat:clear", {})
    await waitFor(() => expect(screen.queryByText("System message")).not.toBeInTheDocument())
  })

  it("clearMessages empties the feed but keeps the typed-message recall history", async () => {
    render(<App />)
    nui("qbchat:message", { id: "one", args: ["System message"] })
    await screen.findByText("System message")
    nui("qbchat:clearMessages", {})
    await waitFor(() => expect(screen.queryByText("System message")).not.toBeInTheDocument())
  })

  it("places the input box itself at the /hudlayout spot, in root pixels rather than vw/vh", async () => {
    const { container } = render(<App />)
    nui("qbchat:open", {})
    await screen.findByLabelText("Chat message")
    act(() => nui("qbchat:inputOffset", { x: 0.25, y: 0.5, scale: 1.25 }))

    // jsdom is 1024x768, so the shared NUI root is 1920x1440 root pixels.
    const shell = container.querySelector<HTMLElement>(".chat-shell")!
    await waitFor(() => expect(shell).toHaveStyle({ left: `${16 + 0.25 * 1920}px`, top: `${16 + 0.5 * 1440}px` }))
    expect(shell.style.transform).toBe("scale(1.25)")
    expect(shell.style.transformOrigin).toBe("top left")
    expect(container.querySelector(".chat-shell > .composer")).not.toBeNull()
  })

  describe("the chat block does not move or resize as messages are added", () => {
    const rule = (selector: string) => {
      const start = css.indexOf(`${selector} {`)
      expect(start, `${selector} rule`).toBeGreaterThanOrEqual(0)
      return css.slice(start, css.indexOf("}", start))
    }

    // jsdom has no layout engine, so the guarantee is asserted as the contract
    // that produces it: inline geometry computed from config and layout only,
    // an out-of-flow history with a fixed height, and an input-sized shell.
    function blockGeometry(container: HTMLElement) {
      const shell = container.querySelector<HTMLElement>(".chat-shell")!
      const feed = container.querySelector<HTMLElement>(".message-feed")!
      return {
        shell: shell.getAttribute("style"),
        placement: feed.classList.contains("above") ? "above" : feed.classList.contains("below") ? "below" : "none",
        height: feed.style.height,
        top: feed.style.top,
        bottom: feed.style.bottom,
      }
    }

    it("keeps the shell and history geometry identical from 0 to 200 messages, open and closed", async () => {
      const { container } = render(<App />)
      act(() => nui("qbchat:inputOffset", { x: 0.05, y: 0.7, scale: 1.1 }))
      const closed = blockGeometry(container)
      expect(closed.placement).toBe("above")
      expect(closed.bottom).toBe("calc(100% + 6px)")
      expect(container.querySelector(".composer-spacer")).not.toBeNull()

      nui("qbchat:open", {})
      await screen.findByLabelText("Chat message")
      expect(blockGeometry(container)).toEqual(closed)

      act(() => {
        for (let index = 0; index < 200; index += 1) {
          nui("qbchat:message", { id: `size:${index}`, args: [`message ${index}`] })
        }
      })
      expect(blockGeometry(container)).toEqual(closed)

      act(() => nui("qbchat:clearMessages", {}))
      expect(blockGeometry(container)).toEqual(closed)
    })

    it("sizes the history as historyHeight percent of the screen, honouring the legacy key and clamping", () => {
      const { container } = render(<App />)
      const height = () => parseFloat(container.querySelector<HTMLElement>(".message-feed")!.style.height)
      expect(height()).toBeCloseTo(0.32 * 1440, 6)
      act(() => nui("qbchat:init", { config: { historyHeight: 50 } }))
      expect(height()).toBeCloseTo(0.5 * 1440, 6)
      act(() => nui("qbchat:init", { config: { historyHeight: 500 } }))
      expect(height()).toBeLessThanOrEqual(1440)
      act(() => nui("qbchat:init", { config: { historyHeight: undefined, openHistoryHeight: 45 } }))
      expect(height()).toBeCloseTo(0.45 * 1440, 6)
    })

    it("uses Config.chat.position until the player places the chat, for top and bottom anchors", () => {
      const { container } = render(<App />)
      const shell = container.querySelector<HTMLElement>(".chat-shell")!
      expect(shell).toHaveStyle({ left: "16px", top: `${40 + 0.32 * 1440 + 6}px` })
      act(() => nui("qbchat:init", { config: { position: { anchor: "bottom", x: 20, y: 120 } } }))
      expect(shell).toHaveStyle({ left: "20px", top: `${1440 - 120 - 48}px` })
    })

    it("puts the history below an input placed at the top of the screen", () => {
      const { container } = render(<App />)
      act(() => nui("qbchat:inputOffset", { x: 0, y: 0.02, scale: 1 }))
      const feed = container.querySelector<HTMLElement>(".message-feed")!
      expect(feed).toHaveClass("below")
      expect(feed.style.top).toBe("calc(100% + 6px)")
    })

    it("styles the history as an out-of-flow, transparent region with no content sizing", () => {
      const feed = rule(".message-feed")
      expect(feed).toMatch(/position: absolute/)
      expect(feed).not.toMatch(/max-height|min-height|\bheight:/)
      expect(feed).not.toMatch(/background|border/)
      expect(css).toMatch(/\.message-feed\.above > :first-child \{ margin-top: auto; \}/)
      expect(css).not.toMatch(/\.message-feed[^{]*\{[^}]*max-height/)
      expect(rule(".chat-shell")).not.toMatch(/display: flex|height/)
      expect(rule(".composer")).not.toMatch(/margin/)
      expect(rule(".composer-spacer")).toMatch(/height: 48px/)
      expect(rule(".message-row")).toMatch(/flex: none/)
    })

    it("takes the suggestion panel out of the flow so it cannot move the input", () => {
      expect(rule(".suggestion-panel")).toMatch(/position: absolute/)
      expect(rule(".suggestion-panel.above-input")).toMatch(/bottom: calc\(100% \+ 6px\)/)
    })
  })

  it("keeps only the newest two hundred received messages", () => {
    const { container } = render(<App />)
    act(() => {
      for (let index = 0; index <= 200; index += 1) {
        nui("qbchat:message", { id: `message:${index}`, args: [`message ${index}`] })
      }
    })

    expect(container.querySelectorAll(".message-row")).toHaveLength(200)
    expect(screen.queryByText("message 0")).not.toBeInTheDocument()
    expect(screen.getByText("message 200")).toBeInTheDocument()
  })

  it("discards a stale dynamic argument response", async () => {
    const pending: Array<(response: { ok: boolean; json: () => Promise<unknown> }) => void> = []
    vi.stubGlobal("fetch", vi.fn((input: string | URL | Request) => {
      if (String(input).endsWith("/qbchat:suggest")) {
        return new Promise((resolve) => pending.push(resolve))
      }
      return Promise.resolve({ ok: true, json: async () => ({}) })
    }))

    render(<App />)
    nui("qbchat:suggestionAdd", {
      name: "/giveitem", help: "Give item", params: [{ name: "item", hasSuggestions: true }],
    })
    nui("qbchat:open", {})
    const input = await screen.findByLabelText("Chat message")

    fireEvent.change(input, { target: { value: "/giveitem al" } })
    await waitFor(() => expect(pending).toHaveLength(1))
    fireEvent.change(input, { target: { value: "/giveitem be" } })
    await waitFor(() => expect(pending).toHaveLength(2))

    pending[1]({ ok: true, json: async () => [{ value: "beta" }] })
    await screen.findByText("beta")
    pending[0]({ ok: true, json: async () => [{ value: "alpha" }] })
    await act(async () => Promise.resolve())
    expect(screen.queryByText("alpha")).not.toBeInTheDocument()
    expect(screen.getByText("beta")).toBeInTheDocument()
  })

  it("fades the closed feed after the configured timeout", () => {
    vi.useFakeTimers()
    render(<App />)
    act(() => nui("qbchat:message", { id: "fade", args: ["Temporary message"] }))
    const feed = screen.getByText("Temporary message").closest("section")
    expect(feed).toHaveClass("visible")

    act(() => vi.advanceTimersByTime(8001))
    expect(feed).toHaveClass("hidden")
    vi.useRealTimers()
  })

  it("uses registered compatibility templates without allowing raw script markup", async () => {
    render(<App />)
    nui("qbchat:templateAdd", { id: "notice", template: "<strong>{0}</strong><script>bad()</script>" })
    nui("qbchat:message", { id: "template", templateId: "notice", args: ["Safe notice"] })
    const notice = await screen.findByText("Safe notice")
    expect(notice.tagName).toBe("STRONG")
    expect(screen.queryByText("bad()")).not.toBeInTheDocument()
  })
})
