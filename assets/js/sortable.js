import Sortable from "sortablejs"

export default {
  mounted() {
    setupSortable(this)
  }
}

const setupSortable = (viewHook) => {
  new Sortable(viewHook.el, {
    draggable: ".item-draggable",
    handle: ".sortable-handle",
    animation: 150,
    onEnd: ({oldIndex, newIndex}) => {
      viewHook.pushEvent("reorder", {
        oldIndex: oldIndex - 1, 
        newIndex: newIndex - 1
      })
    }
  })
}


