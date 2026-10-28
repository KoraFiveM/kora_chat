import { useEffect, useRef } from "react"

declare global {
  interface Window {
    GetParentResourceName?: () => string
  }
}

export const isNui = typeof window.GetParentResourceName === "function"

export async function fetchNui<T = unknown>(callback: string, data: unknown = {}): Promise<T> {
  if (!isNui) return {} as T
  const resource = window.GetParentResourceName?.() ?? "kora_chat"
  const response = await fetch(`https://${resource}/${callback}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  })
  if (!response.ok) throw new Error(`NUI callback ${callback} failed: ${response.status}`)
  return response.json() as Promise<T>
}

export function useNuiEvent<T>(action: string, handler: (data: T) => void) {
  const handlerRef = useRef(handler)
  handlerRef.current = handler

  useEffect(() => {
    const listener = (event: MessageEvent<{ action?: string; data?: T }>) => {
      if (event.data?.action === action) handlerRef.current(event.data.data as T)
    }
    window.addEventListener("message", listener)
    return () => window.removeEventListener("message", listener)
  }, [action])
}
