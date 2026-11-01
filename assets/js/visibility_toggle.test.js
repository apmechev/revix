/**
 * Tests for visibility_toggle.js — VisibilityToggle LiveView hook
 *
 * Run with: npm test (from assets/ directory)
 */
import { describe, it, expect, beforeEach, afterEach } from "vitest"
import { createVisibilityToggleHook } from "./visibility_toggle.js"

function buildToggle() {
  const el = document.createElement("div")
  el.dataset.visibility = "public"
  el.innerHTML = `
    <button type="button" data-visibility-option="public" aria-pressed="true">Public</button>
    <button type="button" data-visibility-option="instance" aria-pressed="false">Instance</button>
    <button type="button" data-visibility-option="followers" aria-pressed="false">Followers</button>
    <button type="button" data-visibility-option="private" aria-pressed="false">Private</button>
    <input type="hidden" name="post[visibility]" value="public" />
  `
  document.body.appendChild(el)

  const hook = createVisibilityToggleHook()
  hook.el = el
  hook.mounted()
  return { el, hook }
}

function clickOption(el, value) {
  const btn = el.querySelector(`[data-visibility-option="${value}"]`)
  btn.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))
}

describe("VisibilityToggle hook", () => {
  beforeEach(() => {
    document.body.innerHTML = ""
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  it("moves the highlight and syncs the hidden input on click", () => {
    const { el } = buildToggle()
    const input = el.querySelector("input[type=hidden]")
    const events = []
    input.addEventListener("input", (e) => events.push(e.type))
    input.addEventListener("change", (e) => events.push(e.type))

    clickOption(el, "private")

    expect(el.dataset.visibility).toBe("private")
    expect(input.value).toBe("private")
    expect(events).toEqual(["input", "change"])
  })

  it("updates aria-pressed across all options", () => {
    const { el } = buildToggle()

    clickOption(el, "followers")

    const pressed = [...el.querySelectorAll("[data-visibility-option]")].map((b) => [
      b.dataset.visibilityOption,
      b.getAttribute("aria-pressed"),
    ])
    expect(pressed).toEqual([
      ["public", "false"],
      ["instance", "false"],
      ["followers", "true"],
      ["private", "false"],
    ])
  })

  it("does not dispatch events when the value is unchanged", () => {
    const { el } = buildToggle()
    const input = el.querySelector("input[type=hidden]")
    let fired = 0
    input.addEventListener("input", () => fired++)
    input.addEventListener("change", () => fired++)

    clickOption(el, "public")

    expect(el.dataset.visibility).toBe("public")
    expect(fired).toBe(0)
  })

  it("ignores clicks outside the option buttons", () => {
    const { el } = buildToggle()

    el.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }))

    expect(el.dataset.visibility).toBe("public")
  })
})
