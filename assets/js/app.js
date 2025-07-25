// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Hooks for LiveView
let Hooks = {}

// Flash message hook
Hooks.Flash = {
  mounted() {
    let hideTimer = setTimeout(() => {
      this.el.click()
    }, 5000)
    this.el.addEventListener("click", () => {
      clearTimeout(hideTimer)
    })
  }
}

// VSM System Monitor Hook
Hooks.SystemMonitor = {
  mounted() {
    // Update system metrics
    this.updateMetrics = () => {
      // Simulate real-time metrics
      const metrics = {
        cpu: Math.random() * 100,
        memory: Math.random() * 100,
        variety: Math.random() * 0.5 + 0.5,
        connections: Math.floor(Math.random() * 50) + 10
      }
      
      this.pushEvent("update-metrics", metrics)
    }
    
    // Update every 2 seconds
    this.timer = setInterval(this.updateMetrics, 2000)
  },
  
  destroyed() {
    clearInterval(this.timer)
  }
}

// VSM Neural Network Animation Hook
Hooks.NeuralAnimation = {
  mounted() {
    const canvas = this.el
    const ctx = canvas.getContext("2d")
    canvas.width = canvas.offsetWidth
    canvas.height = canvas.offsetHeight
    
    const particles = []
    const connections = []
    
    // Create neural nodes
    for (let i = 0; i < 20; i++) {
      particles.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        vx: (Math.random() - 0.5) * 0.5,
        vy: (Math.random() - 0.5) * 0.5,
        radius: Math.random() * 3 + 1
      })
    }
    
    const animate = () => {
      ctx.fillStyle = "rgba(5, 5, 5, 0.1)"
      ctx.fillRect(0, 0, canvas.width, canvas.height)
      
      // Update and draw particles
      particles.forEach((p, i) => {
        p.x += p.vx
        p.y += p.vy
        
        if (p.x < 0 || p.x > canvas.width) p.vx *= -1
        if (p.y < 0 || p.y > canvas.height) p.vy *= -1
        
        ctx.beginPath()
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2)
        ctx.fillStyle = "#00ff41"
        ctx.fill()
        
        // Draw connections
        particles.forEach((p2, j) => {
          if (i < j) {
            const dist = Math.sqrt((p.x - p2.x) ** 2 + (p.y - p2.y) ** 2)
            if (dist < 100) {
              ctx.beginPath()
              ctx.moveTo(p.x, p.y)
              ctx.lineTo(p2.x, p2.y)
              ctx.strokeStyle = `rgba(0, 255, 65, ${1 - dist / 100})`
              ctx.lineWidth = 0.5
              ctx.stroke()
            }
          }
        })
      })
      
      requestAnimationFrame(animate)
    }
    
    animate()
  }
}

// VSM Command Terminal Hook
Hooks.CommandTerminal = {
  mounted() {
    this.history = []
    this.historyIndex = -1
    
    const input = this.el.querySelector("input")
    const output = this.el.querySelector(".terminal-output")
    
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        const command = input.value.trim()
        if (command) {
          this.history.push(command)
          this.historyIndex = this.history.length
          this.pushEvent("execute-command", {command})
          input.value = ""
        }
      } else if (e.key === "ArrowUp") {
        e.preventDefault()
        if (this.historyIndex > 0) {
          this.historyIndex--
          input.value = this.history[this.historyIndex]
        }
      } else if (e.key === "ArrowDown") {
        e.preventDefault()
        if (this.historyIndex < this.history.length - 1) {
          this.historyIndex++
          input.value = this.history[this.historyIndex]
        } else {
          this.historyIndex = this.history.length
          input.value = ""
        }
      }
    })
    
    this.handleEvent("command-output", ({output}) => {
      const line = document.createElement("div")
      line.className = "terminal-line"
      line.textContent = output
      output.appendChild(line)
      output.scrollTop = output.scrollHeight
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#00ff41"}, shadowColor: "rgba(0, 255, 65, .5)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// VSM-specific JavaScript utilities
window.VSM = {
  // Format variety score
  formatVariety: (score) => {
    return (score * 100).toFixed(1) + "%"
  },
  
  // System status helpers
  getStatusColor: (status) => {
    const colors = {
      operational: "#00ff41",
      degraded: "#ffaa00",
      critical: "#ff0080",
      unknown: "#666666"
    }
    return colors[status] || colors.unknown
  },
  
  // Animation utilities
  animateValue: (element, start, end, duration) => {
    const range = end - start
    const startTime = performance.now()
    
    const animate = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      const value = start + (range * progress)
      
      element.textContent = value.toFixed(2)
      
      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }
    
    requestAnimationFrame(animate)
  }
}