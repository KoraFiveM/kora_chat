import { describe, expect, it } from "vitest"
import {
  completeArgument,
  filterCommands,
  limitCharacters,
  parseCommand,
  renderCompatibilityTemplate,
} from "./chat"
import type { CommandSuggestion } from "./types"

const command: CommandSuggestion = {
  name: "/giveitem",
  help: "Give an item",
  params: [
    { name: "player", help: "Server id", hasSuggestions: true },
    { name: "item", help: "Item name", hasSuggestions: true },
  ],
}

describe("command parsing", () => {
  it("filters command names by prefix", () => {
    expect(filterCommands("/giv", [command, { name: "/goto", help: "", params: [] }], 8)).toEqual([command])
  })

  it("identifies and caps the active argument", () => {
    expect(parseCommand("/giveitem 12 wa", command)).toMatchObject({
      command: "giveitem", argumentIndex: 2, query: "wa", exact: true,
    })
    expect(parseCommand("/giveitem 12 water extra", command)?.argumentIndex).toBe(2)
    expect(parseCommand("/giveitem  ", command)?.argumentIndex).toBe(1)
  })

  it("replaces the current argument for Tab completion", () => {
    expect(completeArgument("/giveitem 12 wa", "water_bottle")).toBe("/giveitem 12 water_bottle ")
  })

  it("limits Unicode text by characters rather than UTF-16 code units", () => {
    expect(limitCharacters("😀😀a", 2)).toBe("😀😀")
  })
})

describe("compatibility template sanitization", () => {
  it("escapes arguments and removes executable markup", () => {
    const result = renderCompatibilityTemplate("<b>{0}</b><script>alert(1)</script>", ["<img src=x onerror=1>"])
    expect(result).toContain("&lt;img src=x onerror=1&gt;")
    expect(result).not.toContain("script")
  })
})
