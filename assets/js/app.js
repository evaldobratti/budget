// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"
import { Prompt } from "primer-live";
import "primer-live/primer-live.css";

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const Hooks = {
  Prompt,
  BSInputError: {
    updated() {
      const input = this.el
      const feedback = document.querySelector(`[phx-feedback-for='${input.name}']`)
      console.info(this.el.id)

      if (!feedback || feedback.classList.contains('phx-no-feedback')) return

      input.classList.add('is-invalid')
    },
  },
  OpenDialog: {
    mounted() {
      Prompt.show(this.el, {
        didHide: () => {
          this.liveSocket.pushHistoryPatch(this.el.dataset["returnTo"], "push", this.el)
        }
      })
    }
  }
}


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  dom: {
    onBeforeElUpdated(from, to){
      if(from && from._x_dataStack){ window.Alpine.clone(from, to) }
    }
  },
  params: {_csrf_token: csrfToken}, hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

