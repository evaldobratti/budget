// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import { Prompt } from "primer-live";
import "primer-live/primer-live.css";
import "../css/app.css"

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
import Alpine from 'alpinejs'
import { offset, flip, shift, computePosition, autoUpdate, arrow } from "@floating-ui/dom"
import Sortable from "sortablejs"
 
window.Alpine = Alpine
Alpine.start()

const Hooks = {
  Prompt,
  BSInputError: {
    updated() {
      const input = this.el
      const feedback = document.querySelector(`[phx-feedback-for='${input.name}']`)

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
  },
}

const setupTooltip = (tooltip) => {
  const arrowElement = tooltip.querySelector(".arrow")
  const target = tooltip.nextElementSibling
  const placement = 'top'

  const cleanup = autoUpdate(target, tooltip, function update() {
    computePosition(target, tooltip, {
      placement,
      middleware: [
        offset(8),
        flip(),
        shift({padding: 5}),
        arrow({element: arrowElement})
      ],
    }).then(({x, y, placement, middlewareData}) => {
      Object.assign(tooltip.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
      const {x: arrowX, y: arrowY} = middlewareData.arrow;

      const staticSide = {
        top: 'bottom',
        right: 'left',
        bottom: 'top',
        left: 'right',
      }[placement.split('-')[0]];

      Object.assign(arrowElement.style, {
        left: arrowX != null ? `${arrowX}px` : '',
        top: arrowY != null ? `${arrowY}px` : '',
        right: '',
        bottom: '',
        [staticSide]: '-4px',
      });

    });
  })
   
  function showTooltip() {
    tooltip.style.display = 'block';
  }
   
  function hideTooltip() {
    tooltip.style.display = 'none';
  }

  target.addEventListener("mouseenter", showTooltip)
  target.addEventListener("mouseleave", hideTooltip)
}



let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  dom: {
    onBeforeElUpdated(from, to){
      if (!from) return
      if (!from._x_dataStack) return

      Alpine.clone(from, to)
    },
    onNodeAdded(el) {
      if (el && el.dataset && el.dataset["xtooltip"] === "") {
        setupTooltip(el)
      }
    }
  },
  params: {_csrf_token: csrfToken}, hooks: Hooks
})

const setupSortable = (el) => {
    new Sortable(el, {
      handle: ".sortable-handle",
      animation: 150,
      onEnd: ({oldIndex, newIndex}) => {
        const offsetHeaderBalance = 2

        liveSocket.owner(el, (view) => view.pushHookEvent(null, "reorder", {
          oldIndex: oldIndex - offsetHeaderBalance, 
          newIndex: newIndex - offsetHeaderBalance
        }, () => {}))
      }
    })
}

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())
window.addEventListener("budget:tooltip-setup", event => setupTooltip(event.target))
window.addEventListener("budget:tooltip-cleanup", event => console.info('cleanup', event))
window.addEventListener("budget:sortable-setup", event => setupSortable(event.target))

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

