<script>
import { defineComponent } from 'vue'
import Plotly from 'plotly.js-dist-min'

export default defineComponent({
  name: 'SimRealTimeInstrumentation',
  data() {
    return {
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
    
    // Initialize traces with 50 points
    this.traces.forEach(trace => {
      trace.x = Array.from({ length: 50 }, (_, i) => now - (50 - i) * 100)
      trace.y = Array.from({ length: 50 }, () => Math.floor(Math.random() * 25))
    })

    // Create plot
    Plotly.newPlot(this.$refs.chart, this.traces, this.layout, {
      displayModeBar: false,
      responsive: true
    })

    // Update function
    const update = () => {
      const now = Date.now()
      
      // Update all traces in a single call
      const updates = {
        x: [],
        y: []
      }

      this.traces.forEach(trace => {
        // Remove old points and add new one
        trace.x = trace.x.filter(x => x > now - 5000)
        trace.y = trace.y.slice(-trace.x.length)
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

    // Start updates
    update()
    this.timer = setInterval(update, 100)
  },

  beforeUnmount() {
    if (this.timer) clearInterval(this.timer)
    if (this.$refs.chart) Plotly.purge(this.$refs.chart)
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
