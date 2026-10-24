/**
 * PlaceSearch LiveView hook — pushes browser datetime/timezone on mount for
 * field pre-filling, and wires the optional "Locate me" button to push
 * geolocation coordinates to the LiveView.
 *
 * The set_defaults push always fires, regardless of whether #locate-btn is
 * present, so the hook works on both the full place-search form and the
 * simpler place-first checkin form.
 *
 * When the hook element carries data-auto-locate="true" (driven by the
 * person's "Auto-locate on checkin" preference), geolocation runs
 * automatically on mount and the coordinates are cached client-side. The
 * "locate" event — which triggers the nearby-places search on the server —
 * is only pushed when the user presses "Locate me", reusing the cached
 * coordinates so the search starts immediately.
 */
export function createPlaceSearchHook() {
  return {
    mounted() {
      const now = new Date()
      const pad = n => String(n).padStart(2, "0")
      const localDatetime = `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`
      this.pushEvent("set_defaults", {
        local_datetime: localDatetime,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
      })

      const locateBtn = this.el.querySelector("#locate-btn")
      const locateStatus = this.el.querySelector("#locate-status")
      if (!locateBtn) return

      let locatedCoords = null

      const requestPosition = ({onSuccess, onError}) => {
        navigator.geolocation.getCurrentPosition(
          ({coords: {latitude, longitude, accuracy}}) => {
            locatedCoords = {latitude, longitude, accuracy}
            onSuccess(locatedCoords)
          },
          (err) => {
            locateStatus.textContent = `Error: ${err.message}`
            if (onError) onError(err)
          },
          {enableHighAccuracy: true, timeout: 15000}
        )
      }

      locateBtn.addEventListener("click", () => {
        if (locatedCoords) {
          // Position already detected on mount — search immediately.
          locateStatus.textContent = `Located (±${Math.round(locatedCoords.accuracy)}m)`
          locateBtn.disabled = true
          this.pushEvent("locate", {
            lat: locatedCoords.latitude,
            lon: locatedCoords.longitude,
            accuracy: locatedCoords.accuracy
          })
          return
        }

        if (!navigator.geolocation) {
          locateStatus.textContent = "Geolocation not supported"
          return
        }
        locateStatus.textContent = "Locating..."
        locateBtn.disabled = true
        requestPosition({
          onSuccess: ({latitude, longitude, accuracy}) => {
            locateStatus.textContent = `Located (±${Math.round(accuracy)}m)`
            this.pushEvent("locate", {lat: latitude, lon: longitude, accuracy})
          },
          onError: () => {
            locateBtn.disabled = false
          }
        })
      })

      if (this.el.dataset.autoLocate === "true") {
        // Auto-locate: detect the position now, but don't search — the
        // server-side search only runs when "Locate me" is pressed.
        if (!navigator.geolocation) {
          locateStatus.textContent = "Geolocation not supported"
        } else {
          locateStatus.textContent = "Locating..."
          requestPosition({
            onSuccess: ({accuracy}) => {
              locateStatus.textContent = `Located (±${Math.round(accuracy)}m)`
            }
          })
        }
      }
    },

    updated() {
      const btn = this.el.querySelector("#locate-btn")
      if (btn) btn.disabled = false
    }
  }
}
