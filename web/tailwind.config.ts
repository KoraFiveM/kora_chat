import type { Config } from "tailwindcss"

export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: "hsl(var(--card))",
        popover: "hsl(var(--popover))",
        primary: "hsl(var(--primary))",
        "primary-foreground": "hsl(var(--primary-foreground))",
        muted: "hsl(var(--muted))",
        "muted-foreground": "hsl(var(--muted-foreground))",
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        "surface-raised": "hsl(var(--surface-raised))",
        "surface-hover": "hsl(var(--surface-hover))",
        "brand-soft": "hsl(var(--brand-soft))",
        "brand-border": "hsl(var(--brand-border))",
      },
      boxShadow: {
        low: "0 4px 12px rgb(0 0 0 / 28%)",
        floating: "0 12px 32px rgb(0 0 0 / 42%)",
      },
    },
  },
  plugins: [],
} satisfies Config
