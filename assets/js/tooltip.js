import { offset, flip, shift, computePosition, autoUpdate, arrow } from "@floating-ui/dom"

export default {
  mounted() {
    this.cleanup = setupTooltip(this.el)
  },
  destroyed() {
    this.cleanup()
  }
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

  return () => {
    cleanup()
    target.removeEventListener("mouseenter", showTooltip)
    target.removeEventListener("mouseleave", hideTooltip)
  }
}
