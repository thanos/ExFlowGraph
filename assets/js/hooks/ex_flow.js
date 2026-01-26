export default {
  mounted() {
    this.drag = null
    this.pan = null
    
    // Transform state: scale, translateX, translateY
    this.transform = { scale: 1.0, translateX: 0, translateY: 0 }
    
    // Get the container element that will be transformed
    this.container = this.el.querySelector(".exflow-container") || this.el

    this.onMouseDown = (e) => {
      const nodeEl = e.target.closest(".exflow-node")
      
      // If clicking on a node, start node drag
      if (nodeEl && this.el.contains(nodeEl)) {
        e.preventDefault()

        const id = nodeEl.dataset.id
        const startX = e.clientX
        const startY = e.clientY
        const originX = parseFloat(nodeEl.dataset.x || "0")
        const originY = parseFloat(nodeEl.dataset.y || "0")

        this.drag = { id, nodeEl, startX, startY, originX, originY }
        nodeEl.classList.add("ring-2", "ring-primary/60")

        window.addEventListener("mousemove", this.onMouseMove)
        window.addEventListener("mouseup", this.onMouseUp, { once: true })
        return
      }
      
      // If clicking on canvas background, start pan
      if (e.target === this.el || e.target.classList.contains("exflow-canvas-bg")) {
        e.preventDefault()
        
        this.pan = {
          startX: e.clientX,
          startY: e.clientY,
          originTranslateX: this.transform.translateX,
          originTranslateY: this.transform.translateY
        }
        
        this.el.style.cursor = "grabbing"
        
        window.addEventListener("mousemove", this.onPanMove)
        window.addEventListener("mouseup", this.onPanEnd, { once: true })
      }
    }

    this.onMouseMove = (e) => {
      if (!this.drag) return

      const dx = (e.clientX - this.drag.startX) / this.transform.scale
      const dy = (e.clientY - this.drag.startY) / this.transform.scale

      const x = this.drag.originX + dx
      const y = this.drag.originY + dy

      this.drag.nodeEl.style.transform = `translate(${x}px, ${y}px)`
      this.drag.nodeEl.dataset.x = `${x}`
      this.drag.nodeEl.dataset.y = `${y}`

      this.updateConnectedEdges(this.drag.id)
    }
    
    this.onPanMove = (e) => {
      if (!this.pan) return
      
      const dx = e.clientX - this.pan.startX
      const dy = e.clientY - this.pan.startY
      
      this.transform.translateX = this.pan.originTranslateX + dx
      this.transform.translateY = this.pan.originTranslateY + dy
      
      this.applyTransform()
    }
    
    this.onPanEnd = (_e) => {
      if (!this.pan) return
      
      this.pan = null
      this.el.style.cursor = "grab"
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
    
    this.onWheel = (e) => {
      e.preventDefault()
      
      const delta = -e.deltaY
      const zoomIntensity = 0.001
      const zoomFactor = 1 + delta * zoomIntensity
      
      const oldScale = this.transform.scale
      const newScale = Math.max(0.1, Math.min(3.0, oldScale * zoomFactor))
      
      if (newScale === oldScale) return
      
      // Zoom toward cursor position
      const rect = this.el.getBoundingClientRect()
      const mouseX = e.clientX - rect.left
      const mouseY = e.clientY - rect.top
      
      // Calculate world position before zoom
      const worldX = (mouseX - this.transform.translateX) / oldScale
      const worldY = (mouseY - this.transform.translateY) / oldScale
      
      // Update scale
      this.transform.scale = newScale
      
      // Adjust translation to keep world position under cursor
      this.transform.translateX = mouseX - worldX * newScale
      this.transform.translateY = mouseY - worldY * newScale
      
      this.applyTransform()
    }

    this.el.addEventListener("mousedown", this.onMouseDown)
    this.el.addEventListener("wheel", this.onWheel, { passive: false })
    this.el.style.cursor = "grab"

    // Initial edge layout once DOM is ready
    queueMicrotask(() => this.redrawAllEdges())
  },

  updated() {
    // Redraw all edges after LiveView updates the DOM
    this.redrawAllEdges()
  },

  destroyed() {
    this.el.removeEventListener("mousedown", this.onMouseDown)
    this.el.removeEventListener("wheel", this.onWheel)
    window.removeEventListener("mousemove", this.onMouseMove)
    window.removeEventListener("mousemove", this.onPanMove)
  },
  
  redrawAllEdges() {
    const paths = this.el.querySelectorAll("path.exflow-edge")
    for (const pathEl of paths) {
      const sourceId = pathEl.dataset.sourceId
      const targetId = pathEl.dataset.targetId
      const s = this.getNodeCenter(sourceId)
      const t = this.getNodeCenter(targetId)
      if (!s || !t) continue
      pathEl.setAttribute("d", cubicBezierPath(s.x, s.y, t.x, t.y))
    }
  },
  
  applyTransform() {
    const { scale, translateX, translateY } = this.transform
    this.container.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`
    this.container.style.transformOrigin = "0 0"
  },
  
  screenToWorld(screenX, screenY) {
    const rect = this.el.getBoundingClientRect()
    const x = (screenX - rect.left - this.transform.translateX) / this.transform.scale
    const y = (screenY - rect.top - this.transform.translateY) / this.transform.scale
    return { x, y }
  },
  
  worldToScreen(worldX, worldY) {
    const rect = this.el.getBoundingClientRect()
    const x = worldX * this.transform.scale + this.transform.translateX + rect.left
    const y = worldY * this.transform.scale + this.transform.translateY + rect.top
    return { x, y }
  },

  updateConnectedEdges(nodeId) {
    const paths = this.el.querySelectorAll(
      `path.exflow-edge[data-source-id='${nodeId}'], path.exflow-edge[data-target-id='${nodeId}']`
    )

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
