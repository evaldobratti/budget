import Sortable from "sortablejs"

export default {
  mounted() {
    setupSortable(this.el)
  }
}

const setupSortable = (el) => {
  new Sortable(el, {
    draggable: ".item-draggable",
    handle: ".sortable-handle",
    animation: 150,
    onEnd: ({oldIndex, newIndex}) => {
      const offsetHeaderBalance = 1

      window.liveSocket.owner(el, (view) => view.pushHookEvent(null, "reorder", {
        oldIndex: oldIndex - offsetHeaderBalance, 
        newIndex: newIndex - offsetHeaderBalance
      }, () => {}))
    }
  })
}


