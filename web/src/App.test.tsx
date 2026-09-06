import { act, fireEvent, render, screen, waitFor } from "@testing-library/react"
import { beforeEach, describe, expect, it, vi } from "vitest"
import App from "./App"

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

  it("clears received messages", async () => {
    render(<App />)
    nui("qbchat:message", { id: "one", args: ["System message"] })
    await screen.findByText("System message")
    nui("qbchat:clear", {})
    await waitFor(() => expect(screen.queryByText("System message")).not.toBeInTheDocument())
  })

  it("moves only the chat composer when the HUD supplies an input offset", async () => {
    const { container } = render(<App />)
    nui("qbchat:open", {})
    await screen.findByLabelText("Chat message")
    act(() => nui("qbchat:inputOffset", { x: 0.25, y: -0.1 }))

    await waitFor(() => expect(container.querySelector(".composer")).toHaveStyle({ transform: "translate(25vw, -10vh)" }))
    expect(container.querySelector(".message-feed")).not.toHaveStyle({ transform: "translate(25vw, -10vh)" })
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
