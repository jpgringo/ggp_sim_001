<script>
import { defineComponent } from 'vue'
import Plotly from 'plotly.js-dist-min'

export default defineComponent({
  name: 'SimRealTimeInstrumentation',
  data() {
    return {
      animationFrame: null,
      resizeObserver: null,
      lastUpdate: 0,
      timer: null,
      layout: {
        xaxis: {
          range: [0, 2500],
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
  props: {
    xAxisStep: {
      type: Number,
      default: 50
    },
    yAxisStep: {
      type: Number,
      default: 10
    },
    agentTraces: {
      type: Array,
      required: true,
      default: () => ([
      { name: 'Agent 1', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#FF1919', width: 2 } },
      { name: 'Agent 2', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#19FF19', width: 2 } },
      { name: 'Agent 3', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#1919FF', width: 2 } },
      { name: 'Agent 4', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#FFB619', width: 2 } }
    ])},

  },
  mounted() {
    // Create plot
    Plotly.newPlot(this.$refs.chart, this.agentTraces, this.layout, {
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
      const maxX = Math.ceil(this.agentTraces.reduce((acc, series) => {
        console.log(`series:`, series);
        const lastX = series.x.length > 0 ? series.x[series.x.length - 1] : 0
        acc = Math.max(acc, lastX)
        return acc
      }, 0) / this.xAxisStep) * this.xAxisStep

      let yValues = this.agentTraces.flatMap(trace => trace.y);
      console.log(`yValues:`, yValues);
      const maxY = Math.ceil(Math.max(...yValues)/this.yAxisStep) * this.yAxisStep

      console.log(`maxX=${maxX}`);
      console.log(`maxY=${maxY}`);

        // Update plot with all traces at once
        Plotly.update(
          this.$refs.chart,
          this.agentTraces,
          { 'xaxis.range': [0, maxX],
            'yaxis.range': [0, maxY]}
        )
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
