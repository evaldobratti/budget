import { offset, flip, shift, computePosition, autoUpdate, arrow } from "@floating-ui/dom"

export default {
  mounted() {
    this.cleanup = setupPopover(this, this.el)
  },
  destroyed() {
    this.cleanup()
  }
}

const setupPopover = (instance, handle) => {
  instance.leftTimeout = null
  const popover = handle.nextElementSibling
  const placement = 'top'

  const cleanup = autoUpdate(handle, popover, function update() {
    computePosition(handle, popover, {
      placement,
      middleware: [
        offset(8),
        flip(),
        shift({padding: 5}),
      ],
    }).then(({x, y}) => {
      Object.assign(popover.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    });
  })
   
  function showPopover() {
    clearTimeout(instance.leftTimeout)
    popover.style.display = 'block';
  }
   
  function hidePopover() {
    instance.leftTimeout = setTimeout(() => {
      popover.style.display = 'none';
    }, 400)
  }


  handle.addEventListener("mouseenter", showPopover)
  handle.addEventListener("mouseleave", hidePopover)

  popover.addEventListener("mouseenter", showPopover)
  popover.addEventListener("mouseleave", hidePopover)

  return () => {
    cleanup()
    handle.removeEventListener("mouseenter", showPopover)
    handle.removeEventListener("mouseleave", hidePopover)

    popover.removeEventListener("mouseenter", showPopover)
    popover.removeEventListener("mouseleave", hidePopover)
  }
}
