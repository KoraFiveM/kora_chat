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

  it("moves and scales the whole chat window so the composer stays under the history", async () => {
    const { container } = render(<App />)
    nui("qbchat:open", {})
    await screen.findByLabelText("Chat message")
    act(() => nui("qbchat:inputOffset", { x: 0.25, y: -0.1, scale: 1.25 }))

    await waitFor(() => expect(container.querySelector(".chat-shell")).toHaveStyle({ transform: "translate(25vw, -10vh) scale(1.25)" }))
    expect(container.querySelector(".composer")).not.toHaveStyle({ transform: "translate(25vw, -10vh) scale(1.25)" })
    expect(container.querySelector(".chat-shell > .composer")).not.toBeNull()
  })

  describe("composer position does not change as messages are added", () => {
    const rule = (selector: string) => {
      const start = css.indexOf(`${selector} {`)
      expect(start, `${selector} rule`).toBeGreaterThanOrEqual(0)
      return css.slice(start, css.indexOf("}", start))
    }

    // jsdom has no layout engine, so the position guarantee is asserted as the
    // contract that produces it: a fixed-size history region (inline size
    // variables independent of the messages, no content-sized max-height),
    // bottom-aligned rows, and a composer that is a sibling after the region.
    function feedSizing(container: HTMLElement) {
      const feed = container.querySelector<HTMLElement>(".message-feed")!
      return {
        classes: feed.className.replace(/\b(visible|hidden)\b/g, "").replace(/\s+/g, " ").trim(),
        height: feed.style.getPropertyValue("--history-height"),
        edge: feed.style.getPropertyValue("--chat-edge"),
      }
    }

    it("sizes the history region from config only, never from the message count", async () => {
      const { container } = render(<App />)
      nui("qbchat:open", {})
      await screen.findByLabelText("Chat message")
      const empty = feedSizing(container)
      expect(empty.height).toBe("32vh")
      expect(empty.edge).toBe("40px")
      expect(container.querySelector(".message-feed")).not.toHaveClass("empty")

      act(() => {
        for (let index = 0; index < 200; index += 1) {
          nui("qbchat:message", { id: `size:${index}`, args: [`message ${index}`] })
        }
      })
      expect(feedSizing(container)).toEqual(empty)

      act(() => nui("qbchat:clearMessages", {}))
      expect(feedSizing(container)).toEqual(empty)
    })

    it("keeps the same region size while the input is closed", () => {
      const { container } = render(<App />)
      act(() => nui("qbchat:message", { id: "closed", args: ["one"] }))
      expect(feedSizing(container).height).toBe("32vh")
      expect(container.querySelector(".composer-spacer")).not.toBeNull()
    })

    it("honours historyHeight, the legacy openHistoryHeight, and clamps bad values", () => {
      const { container } = render(<App />)
      act(() => nui("qbchat:init", { config: { historyHeight: 50 } }))
      expect(feedSizing(container).height).toBe("50vh")
      act(() => nui("qbchat:init", { config: { historyHeight: 500 } }))
      expect(feedSizing(container).height).toBe("90vh")
      act(() => nui("qbchat:init", { config: { historyHeight: undefined, openHistoryHeight: 45 } }))
      expect(feedSizing(container).height).toBe("45vh")
    })

    it("uses the configured position edge for the size clamp, for top and bottom anchors", () => {
      const { container } = render(<App />)
      act(() => nui("qbchat:init", { config: { position: { anchor: "bottom", x: 16, y: 120 } } }))
      expect(feedSizing(container).edge).toBe("120px")
      expect(container.querySelector(".chat-shell")).toHaveStyle({ bottom: "120px" })
    })

    it("places the composer directly after the history region, with and without a layout", async () => {
      const { container } = render(<App />)
      nui("qbchat:open", {})
      await screen.findByLabelText("Chat message")
      act(() => nui("qbchat:inputOffset", { x: 0.1, y: 0.2, scale: 1.2 }))
      const children = Array.from(container.querySelector(".chat-shell")!.children)
      expect(children.map((child) => child.className.split(" ")[0])).toEqual(["message-feed", "composer"])
      expect(container.querySelector(".composer-spacer")).toBeNull()
    })

    it("styles the history as a fixed, bottom-aligned, transparent region", () => {
      const feed = rule(".message-feed")
      expect(feed).toMatch(/\bheight: min\(var\(--history-height/)
      expect(feed).toMatch(/flex: none/)
      expect(feed).not.toMatch(/max-height|min-height/)
      expect(feed).not.toMatch(/background|border/)
      expect(css).toMatch(/\.message-feed > :first-child \{ margin-top: auto; \}/)
      expect(css).not.toMatch(/\.message-feed[^{]*\{[^}]*max-height/)
      expect(css).not.toMatch(/\.message-feed\.empty/)
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
