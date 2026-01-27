export default {
  mounted() {
    this.drag = null
    this.pan = null
    this.edgeCreation = null
    
    // Transform state: scale, translateX, translateY
    this.transform = { scale: 1.0, translateX: 0, translateY: 0 }
    
    // Performance optimizations
    this.adjacencyMap = new Map() // node_id -> [edge_ids]
    this.nodeCache = new Map() // node_id -> {x, y, width, height}
    this.pendingEdgeUpdates = new Set() // edge_ids to update
    this.rafId = null
    this.perfMonitor = { dragStart: 0, frameCount: 0, slowFrames: 0 }
    
    // Get the container element that will be transformed
    this.container = this.el.querySelector(".exflow-container") || this.el
    
    // Build adjacency map and cache on mount
    this.buildAdjacencyMap()
    this.cacheNodeGeometry()

    this.onMouseDown = (e) => {
      // Check if clicking on a handle for edge creation
      const handleEl = e.target.closest(".exflow-handle")
      if (handleEl && handleEl.classList.contains("exflow-handle-source")) {
        e.preventDefault()
        e.stopPropagation()
        this.startEdgeCreation(e, handleEl)
        return
      }
      
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
        nodeEl.style.willChange = "transform" // Optimize rendering
        
        // Start performance monitoring
        this.perfMonitor.dragStart = performance.now()
        this.perfMonitor.frameCount = 0
        this.perfMonitor.slowFrames = 0

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
      
      const frameStart = performance.now()

      const dx = (e.clientX - this.drag.startX) / this.transform.scale
      const dy = (e.clientY - this.drag.startY) / this.transform.scale

      const x = this.drag.originX + dx
      const y = this.drag.originY + dy

      // Update node position immediately (no reflow)
      this.drag.nodeEl.style.transform = `translate(${x}px, ${y}px)`
      this.drag.nodeEl.dataset.x = `${x}`
      this.drag.nodeEl.dataset.y = `${y}`
      
      // Update cache
      this.nodeCache.set(this.drag.id, { x, y })

      // Mark connected edges for update (batched in RAF)
      const connectedEdges = this.adjacencyMap.get(this.drag.id) || []
      connectedEdges.forEach(edgeId => this.pendingEdgeUpdates.add(edgeId))
      
      // Schedule batched edge update
      this.scheduleEdgeUpdate()
      
      // Performance monitoring
      const frameTime = performance.now() - frameStart
      this.perfMonitor.frameCount++
      if (frameTime > 16) { // Slower than 60fps
        this.perfMonitor.slowFrames++
      }
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
      nodeEl.style.willChange = "auto" // Clean up rendering hint
      
      // Log performance stats
      const dragDuration = performance.now() - this.perfMonitor.dragStart
      if (this.perfMonitor.frameCount > 0) {
        const avgFrameTime = dragDuration / this.perfMonitor.frameCount
        const slowFramePercent = (this.perfMonitor.slowFrames / this.perfMonitor.frameCount) * 100
        
        if (slowFramePercent > 10) {
          console.warn(`Performance: ${slowFramePercent.toFixed(1)}% slow frames (avg ${avgFrameTime.toFixed(2)}ms)`)
        }
      }

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
    // Rebuild performance caches after LiveView updates
    this.buildAdjacencyMap()
    this.cacheNodeGeometry()
    
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
    // Redraw edges to follow transformed nodes
    this.redrawAllEdges()
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

    // Get node position (world coordinates, same space as edges)
    let x = parseFloat(nodeEl.dataset.x || "0")
    let y = parseFloat(nodeEl.dataset.y || "0")
    
    // Check if there's a transform style applied (during drag)
    const transform = nodeEl.style.transform
    if (transform) {
      const match = transform.match(/translate\(([^,]+)px,\s*([^)]+)px\)/)
      if (match) {
        x = parseFloat(match[1])
        y = parseFloat(match[2])
      }
    }

    const w = nodeEl.offsetWidth
    const h = nodeEl.offsetHeight

    return { x: x + w / 2, y: y + h / 2 }
  },
  
  startEdgeCreation(e, handleEl) {
    const nodeId = handleEl.dataset.nodeId
    const handleType = handleEl.dataset.handle
    
    // Get handle position in screen coordinates
    const rect = handleEl.getBoundingClientRect()
    const canvasRect = this.el.getBoundingClientRect()
    const startX = rect.left + rect.width / 2 - canvasRect.left
    const startY = rect.top + rect.height / 2 - canvasRect.top
    
    this.edgeCreation = {
      sourceNodeId: nodeId,
      sourceHandle: handleType,
      startX,
      startY,
      currentX: startX,
      currentY: startY
    }
    
    // Create ghost edge SVG path
    this.createGhostEdge()
    
    // Highlight compatible target handles
    this.highlightTargetHandles()
    
    this.onEdgeCreationMove = this.onEdgeCreationMove.bind(this)
    this.onEdgeCreationEnd = this.onEdgeCreationEnd.bind(this)
    this.onEdgeCreationCancel = this.onEdgeCreationCancel.bind(this)
    
    window.addEventListener("mousemove", this.onEdgeCreationMove)
    window.addEventListener("mouseup", this.onEdgeCreationEnd, { once: true })
    window.addEventListener("keydown", this.onEdgeCreationCancel)
  },
  
  onEdgeCreationMove(e) {
    if (!this.edgeCreation) return
    
    const canvasRect = this.el.getBoundingClientRect()
    this.edgeCreation.currentX = e.clientX - canvasRect.left
    this.edgeCreation.currentY = e.clientY - canvasRect.top
    
    this.updateGhostEdge()
    
    // Check if hovering over a compatible target handle
    const targetHandle = document.elementFromPoint(e.clientX, e.clientY)?.closest(".exflow-handle-target")
    
    // Remove previous hover state
    document.querySelectorAll(".exflow-handle-target.ring-2").forEach(el => {
      el.classList.remove("ring-2", "ring-success")
    })
    
    if (targetHandle && targetHandle.dataset.nodeId !== this.edgeCreation.sourceNodeId) {
      targetHandle.classList.add("ring-2", "ring-success")
    }
  },
  
  onEdgeCreationEnd(e) {
    if (!this.edgeCreation) return
    
    // Check if dropped on a valid target handle
    const targetHandle = document.elementFromPoint(e.clientX, e.clientY)?.closest(".exflow-handle-target")
    
    if (targetHandle && targetHandle.dataset.nodeId !== this.edgeCreation.sourceNodeId) {
      // Valid drop - create edge
      const targetNodeId = targetHandle.dataset.nodeId
      const targetHandleType = targetHandle.dataset.handle
      
      this.pushEvent("create_edge", {
        source_id: this.edgeCreation.sourceNodeId,
        source_handle: this.edgeCreation.sourceHandle,
        target_id: targetNodeId,
        target_handle: targetHandleType
      })
    }
    
    // Cleanup
    this.removeGhostEdge()
    this.removeTargetHighlights()
    window.removeEventListener("mousemove", this.onEdgeCreationMove)
    window.removeEventListener("keydown", this.onEdgeCreationCancel)
    this.edgeCreation = null
  },
  
  onEdgeCreationCancel(e) {
    if (e.key === "Escape" && this.edgeCreation) {
      this.removeGhostEdge()
      this.removeTargetHighlights()
      window.removeEventListener("mousemove", this.onEdgeCreationMove)
      window.removeEventListener("mouseup", this.onEdgeCreationEnd)
      window.removeEventListener("keydown", this.onEdgeCreationCancel)
      this.edgeCreation = null
    }
  },
  
  createGhostEdge() {
    const svg = this.el.querySelector("svg")
    if (!svg) return
    
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    path.setAttribute("id", "ghost-edge")
    path.setAttribute("class", "stroke-primary/50 stroke-2 fill-none pointer-events-none")
    path.setAttribute("stroke-dasharray", "5,5")
    svg.appendChild(path)
    
    this.updateGhostEdge()
  },
  
  updateGhostEdge() {
    const path = this.el.querySelector("#ghost-edge")
    if (!path || !this.edgeCreation) return
    
    const { startX, startY, currentX, currentY } = this.edgeCreation
    const d = cubicBezierPath(startX, startY, currentX, currentY)
    path.setAttribute("d", d)
  },
  
  removeGhostEdge() {
    const path = this.el.querySelector("#ghost-edge")
    if (path) path.remove()
  },
  
  highlightTargetHandles() {
    document.querySelectorAll(".exflow-handle-target").forEach(handle => {
      if (handle.dataset.nodeId !== this.edgeCreation.sourceNodeId) {
        handle.classList.add("ring-2", "ring-primary/30")
      }
    })
  },
  
  removeTargetHighlights() {
    document.querySelectorAll(".exflow-handle-target").forEach(handle => {
      handle.classList.remove("ring-2", "ring-primary/30", "ring-success")
    })
  },
  
  // Performance optimization methods
  
  buildAdjacencyMap() {
    // Build a map of node_id -> [edge_ids] for fast edge lookup
    this.adjacencyMap.clear()
    
    const edges = this.el.querySelectorAll("[data-edge-id]")
    edges.forEach(edge => {
      const edgeId = edge.dataset.edgeId
      const sourceId = edge.dataset.sourceId
      const targetId = edge.dataset.targetId
      
      if (!this.adjacencyMap.has(sourceId)) {
        this.adjacencyMap.set(sourceId, [])
      }
      if (!this.adjacencyMap.has(targetId)) {
        this.adjacencyMap.set(targetId, [])
      }
      
      this.adjacencyMap.get(sourceId).push(edgeId)
      this.adjacencyMap.get(targetId).push(edgeId)
    })
  },
  
  cacheNodeGeometry() {
    // Cache node positions to avoid layout thrashing
    this.nodeCache.clear()
    
    const nodes = this.el.querySelectorAll(".exflow-node")
    nodes.forEach(node => {
      const id = node.dataset.id
      const x = parseFloat(node.dataset.x || "0")
      const y = parseFloat(node.dataset.y || "0")
      
      this.nodeCache.set(id, { x, y })
    })
  },
  
  scheduleEdgeUpdate() {
    // Batch edge updates in a single requestAnimationFrame
    if (this.rafId) return // Already scheduled
    
    this.rafId = requestAnimationFrame(() => {
      this.flushEdgeUpdates()
      this.rafId = null
    })
  },
  
  flushEdgeUpdates() {
    // Update all pending edges in a single batch
    if (this.pendingEdgeUpdates.size === 0) return
    
    this.pendingEdgeUpdates.forEach(edgeId => {
      const edge = this.el.querySelector(`[data-edge-id="${edgeId}"]`)
      if (!edge) return
      
      const sourceId = edge.dataset.sourceId
      const targetId = edge.dataset.targetId
      
      const sourcePos = this.getNodeCenterCached(sourceId)
      const targetPos = this.getNodeCenterCached(targetId)
      
      if (sourcePos && targetPos) {
        const d = cubicBezierPath(sourcePos.x, sourcePos.y, targetPos.x, targetPos.y)
        edge.setAttribute("d", d)
      }
    })
    
    this.pendingEdgeUpdates.clear()
  },
  
  getNodeCenterCached(nodeId) {
    // Use cached position if available, otherwise compute
    const cached = this.nodeCache.get(nodeId)
    if (cached) {
      return { x: cached.x + 12, y: cached.y + 12 } // Offset to center
    }
    
    const node = this.el.querySelector(`[data-id="${nodeId}"]`)
    if (!node) return null
    
    const x = parseFloat(node.dataset.x || "0")
    const y = parseFloat(node.dataset.y || "0")
    
    return { x: x + 12, y: y + 12 }
  },
  
  updateConnectedEdges(nodeId) {
    // Legacy method - now uses batched updates via scheduleEdgeUpdate
    // This is called from updated() lifecycle
    const connectedEdges = this.adjacencyMap.get(nodeId) || []
    connectedEdges.forEach(edgeId => this.pendingEdgeUpdates.add(edgeId))
    this.scheduleEdgeUpdate()
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
