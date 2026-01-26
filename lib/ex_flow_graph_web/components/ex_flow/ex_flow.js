export default {
  mounted() {
    this.drag = null

    this.onMouseDown = (e) => {
      const nodeEl = e.target.closest(".exflow-node")
      if (!nodeEl || !this.el.contains(nodeEl)) return

      e.preventDefault()

      const rect = this.el.getBoundingClientRect()
      const id = nodeEl.dataset.id

      const startX = e.clientX
      const startY = e.clientY

      const originX = parseFloat(nodeEl.dataset.x || "0")
      const originY = parseFloat(nodeEl.dataset.y || "0")

      this.drag = { id, nodeEl, rect, startX, startY, originX, originY }

      nodeEl.classList.add("ring-2", "ring-primary/60")

      window.addEventListener("mousemove", this.onMouseMove)
      window.addEventListener("mouseup", this.onMouseUp, { once: true })
    }

    this.onMouseMove = (e) => {
      if (!this.drag) return

      const dx = e.clientX - this.drag.startX
      const dy = e.clientY - this.drag.startY

      const x = this.drag.originX + dx
      const y = this.drag.originY + dy

      this.drag.nodeEl.style.transform = `translate(${x}px, ${y}px)`
      this.drag.nodeEl.dataset.x = `${x}`
      this.drag.nodeEl.dataset.y = `${y}`

      this.updateConnectedEdges(this.drag.id)
    }

    this.onMouseUp = (_e) => {
      if (!this.drag) return

      const { id, nodeEl } = this.drag
      const x = parseFloat(nodeEl.dataset.x || "0")
      const y = parseFloat(nodeEl.dataset.y || "0")

      nodeEl.classList.remove("ring-2", "ring-primary/60")

      window.removeEventListener("mousemove", this.onMouseMove)
      this.drag = null

      this.pushEvent("update_position", { id, x, y })
    }

    this.el.addEventListener("mousedown", this.onMouseDown)
  },

  destroyed() {
    this.el.removeEventListener("mousedown", this.onMouseDown)
    window.removeEventListener("mousemove", this.onMouseMove)
  },

  updateConnectedEdges(nodeId) {
    const paths = this.el.querySelectorAll(`path.exflow-edge[data-source-id='${nodeId}'], path.exflow-edge[data-target-id='${nodeId}']`)

    for (const pathEl of paths) {
      const sourceId = pathEl.dataset.sourceId
      const targetId = pathEl.dataset.targetId

      const s = this.getNodeCenter(sourceId)
      const t = this.getNodeCenter(targetId)
      if (!s || !t) continue

      pathEl.setAttribute("d", cubicBezierPath(s.x, s.y, t.x, t.y))
    }
  },

  getNodeCenter(id) {
    const nodeEl = this.el.querySelector(`.exflow-node[data-id='${id}']`)
    if (!nodeEl) return null

    const x = parseFloat(nodeEl.dataset.x || "0")
    const y = parseFloat(nodeEl.dataset.y || "0")

    const w = nodeEl.offsetWidth
    const h = nodeEl.offsetHeight

    return { x: x + w / 2, y: y + h / 2 }
  },
}

function cubicBezierPath(xs, ys, xt, yt) {
  const dx = Math.abs(xt - xs)
  const D = Math.max(dx, 80)

  const c1x = xs + D
  const c1y = ys
  const c2x = xt - D
  const c2y = yt

  return `M ${xs} ${ys} C ${c1x} ${c1y}, ${c2x} ${c2y}, ${xt} ${yt}`
}
