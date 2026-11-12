import "@testing-library/jest-dom/vitest"
import { cleanup } from "@testing-library/react"
import { afterEach } from "vitest"

Element.prototype.scrollTo = Element.prototype.scrollTo ?? (() => undefined)
window.GetParentResourceName = () => "kora_chat"

afterEach(() => cleanup())
