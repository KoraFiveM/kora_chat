import DOMPurify from "dompurify"
import type { CommandParam, CommandSuggestion } from "./types"

export interface ParsedCommand {
  command: string
  args: string[]
  argumentIndex: number
  query: string
  exact: boolean
  param?: CommandParam
}

export function normalizeCommandName(name: string): string {
  return name.startsWith("/") ? name : `/${name}`
}

export function limitCharacters(value: string, maximum: number): string {
  const characters = Array.from(value)
  return characters.length <= maximum ? value : characters.slice(0, Math.max(0, maximum)).join("")
}

export function filterCommands(input: string, suggestions: CommandSuggestion[], limit: number): CommandSuggestion[] {
  if (!input.startsWith("/")) return []
  const commandPart = input.slice(0, input.search(/\s/) === -1 ? undefined : input.search(/\s/)).toLowerCase()
  return suggestions
    .filter((suggestion) => normalizeCommandName(suggestion.name).toLowerCase().startsWith(commandPart))
    .sort((a, b) => normalizeCommandName(a.name).localeCompare(normalizeCommandName(b.name)))
    .slice(0, limit)
}

export function parseCommand(input: string, suggestion?: CommandSuggestion): ParsedCommand | null {
  if (!input.startsWith("/")) return null
  const body = input.slice(1)
  const commandEnd = body.search(/\s/)
  const command = (commandEnd === -1 ? body : body.slice(0, commandEnd)).toLowerCase()
  const exact = suggestion ? normalizeCommandName(suggestion.name).slice(1).toLowerCase() === command : false
  if (commandEnd === -1) return { command, args: [], argumentIndex: 0, query: "", exact }

  const rawArguments = body.slice(commandEnd + 1)
  const trailingSpace = rawArguments.endsWith(" ")
  const trimmedArguments = rawArguments.trim()
  const args = trimmedArguments === "" ? [] : trimmedArguments.split(/\s+/)
  let argumentIndex = trailingSpace ? args.length + 1 : Math.max(args.length, 1)
  if (suggestion?.params.length) argumentIndex = Math.min(argumentIndex, suggestion.params.length)
  const query = trailingSpace ? "" : (args[argumentIndex - 1] ?? "")
  return { command, args, argumentIndex, query, exact, param: suggestion?.params[argumentIndex - 1] }
}

export function completeCommand(name: string): string {
  return `${normalizeCommandName(name)} `
}

export function completeArgument(input: string, value: string): string {
  const firstSpace = input.search(/\s/)
  if (firstSpace === -1) return `${input} ${value} `
  const prefix = input.slice(0, firstSpace)
  const rawArguments = input.slice(firstSpace + 1)
  const trailingSpace = rawArguments.endsWith(" ")
  const args = rawArguments.trim() === "" ? [] : rawArguments.trim().split(/\s+/)
  if (trailingSpace) args.push(value)
  else if (args.length === 0) args.push(value)
  else args[args.length - 1] = value
  return `${prefix} ${args.join(" ")} `
}

export function escapeHtml(value: unknown): string {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")
}

export function renderCompatibilityTemplate(
  template: string,
  args: unknown[] = [],
  params: Record<string, unknown> = {},
): string {
  const substituted = template
    .replace(/\{(\d+)\}/g, (_, index: string) => escapeHtml(args[Number(index)]))
    .replace(/\{\{([a-zA-Z0-9_-]+)\}\}/g, (_, key: string) => escapeHtml(params[key]))
    .replace(/\^(?:[0-9*_~=r/]|#[0-9a-fA-F]{3,6})/g, "")

  return DOMPurify.sanitize(substituted, {
    ALLOWED_TAGS: ["b", "strong", "i", "em", "u", "span", "br", "code"],
    ALLOWED_ATTR: [],
  })
}
