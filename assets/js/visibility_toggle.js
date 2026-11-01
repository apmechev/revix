// Segmented visibility toggle (posts/checkins). Clicking an option moves the
// sliding highlight by setting data-visibility on the container (the pill's
// position is pure CSS, like the theme toggle), updates the hidden form input,
// and dispatches input/change so the form's phx-change revalidates server-side.
export function createVisibilityToggleHook() {
  return {
    mounted() {
      this.el.addEventListener("click", (e) => {
        const btn = e.target.closest("[data-visibility-option]")
        if (!btn || !this.el.contains(btn)) return
        e.preventDefault()

        const value = btn.dataset.visibilityOption
        this.el.dataset.visibility = value

        this.el.querySelectorAll("[data-visibility-option]").forEach((b) => {
          b.setAttribute("aria-pressed", b === btn ? "true" : "false")
        })

        const input = this.el.querySelector("input[type=hidden]")
        if (input && input.value !== value) {
          input.value = value
          input.dispatchEvent(new Event("input", { bubbles: true }))
          input.dispatchEvent(new Event("change", { bubbles: true }))
        }
      })
    },
  }
}
