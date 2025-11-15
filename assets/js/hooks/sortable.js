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
    onEnd: ({oldDraggableIndex, newDraggableIndex}) => {
      viewHook.pushEvent("reorder", {
        oldIndex: oldDraggableIndex, 
        newIndex: newDraggableIndex
      })
    }
  })
}


