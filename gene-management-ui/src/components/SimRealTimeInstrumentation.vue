<script>
import { defineComponent } from 'vue'
import Plotly from 'plotly.js-dist-min'

export default defineComponent({
  name: 'SimRealTimeInstrumentation',
  data() {
    const maxPoints = 50
    return {
      animationFrame: null,
      resizeObserver: null,
      lastUpdate: 0,
      timer: null,
      traces: [
        { name: 'Agent 1', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#FF1919', width: 2 } },
        { name: 'Agent 2', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#19FF19', width: 2 } },
        { name: 'Agent 3', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#1919FF', width: 2 } },
        { name: 'Agent 4', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#FFB619', width: 2 } }
      ],
      layout: {
        xaxis: {
          range: [Date.now() - 5000, Date.now()],
          title: 'Time (ms)'
        },
        yaxis: {
          range: [0, 25],
          title: 'Event Count'
        },
        height: 400,
        margin: { t: 20, l: 60, r: 40, b: 40 },
        showlegend: true
      }
    }
  },

  mounted() {
    const now = Date.now()
    
    // Pre-allocate arrays for better performance
    const maxPoints = 50
    this.traces.forEach(trace => {
      trace.x = new Array(maxPoints).fill(0)
      trace.y = new Array(maxPoints).fill(0)
      for (let i = 0; i < maxPoints; i++) {
        trace.x[i] = now - (maxPoints - i) * 100
        trace.y[i] = Math.floor(Math.random() * 25)
      }
    })

    // Create plot
    Plotly.newPlot(this.$refs.chart, this.traces, this.layout, {
      displayModeBar: false,
      responsive: true,
      transition: {
        duration: 0,
        easing: 'cubic-in-out'
      }
    })

    // Handle resize
    this.resizeObserver = new ResizeObserver(() => {
      Plotly.Plots.resize(this.$refs.chart)
    })
    this.resizeObserver.observe(this.$refs.chart)

    // Update function using requestAnimationFrame
    const update = () => {
      const now = Date.now()
      const elapsed = now - this.lastUpdate

      // Limit updates to ~10 FPS for performance
      if (elapsed > 100) {
        this.lastUpdate = now
      
      // Update all traces in a single call
      const updates = {
        x: [],
        y: []
      }

      this.traces.forEach(trace => {
        // Use circular buffer approach
        trace.x.shift()
        trace.y.shift()
        trace.x.push(now)
        trace.y.push(Math.floor(Math.random() * 25))

        updates.x.push([...trace.x])
        updates.y.push([...trace.y])
      })

        // Update plot with all traces at once
        Plotly.update(
          this.$refs.chart,
          updates,
          { 'xaxis.range': [now - 5000, now] }
        )
      }

      // Schedule next update
      this.animationFrame = requestAnimationFrame(update)
    }

    // Start updates
    update()
  },

  beforeUnmount() {
    if (this.animationFrame) cancelAnimationFrame(this.animationFrame)
    if (this.$refs.chart) {
      this.resizeObserver.unobserve(this.$refs.chart)
      this.resizeObserver.disconnect()
      Plotly.purge(this.$refs.chart)
    }
  }
})
</script>

<template>
  <div class="instrumentation real-time">
    <div ref="chart" class="chart-container"></div>
  </div>
</template>

<style scoped>
.chart-container {
  width: 100%;
  height: 400px;
  background: #fff;
  border: 1px solid #ddd;
  border-radius: 4px;
}
</style>
