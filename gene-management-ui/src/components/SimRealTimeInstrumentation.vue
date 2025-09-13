<script setup>
import { ref, onMounted, onBeforeUnmount, watchEffect, computed } from 'vue'
import Plotly from 'plotly.js-dist-min'

const props = defineProps({
  xAxisStep: { type: Number, default: 50 },
  yAxisStep: { type: Number, default: 10 },
  agentData: { type: Object, required: true },
})

const chart = ref(null)
const resizeObserver = ref(null)

// Maps agentId -> trace index, and agentId -> last processed length
const traceIndexById = ref(new Map())
const lastLenById = ref(new Map())

const agents = computed(() => props.agentData?.agents ?? [])
const dataVersion = computed(() => props.agentData?.version ?? 0)

const palette = ['#FF1919', '#19FF19', '#1919FF', '#FFB619', '#9B59B6', '#1ABC9C', '#F39C12', '#2ECC71']
const colorForIndex = (i) => palette[i % palette.length]

function buildTracesFromAgents(currAgents) {
  return currAgents.map((d, i) => {
    const xArr = [...(d.x ?? [])]
    const yArr = [...(d.y ?? [])]
    const hasData = xArr.length > 0 && yArr.length > 0
    return {
      uid: d.id ?? `trace-${i}`,
      name: d.id ?? `Trace ${i + 1}`,
      type: 'scatter',
      mode: 'lines',
      line: { color: colorForIndex(i), width: 2 },
      x: hasData ? xArr : [0],
      y: hasData ? yArr : [null],
      // Show in legend even if there is no data yet
      visible: hasData ? true : 'legendonly',
    }
  })
}

const baseLayout = {
  xaxis: { range: [0, 500], title: 'Time (ms)' },
  yaxis: { range: [0, 10], title: 'Event Count' },
  height: 400,
  margin: { t: 20, l: 60, r: 40, b: 40 },
  showlegend: true,
}

onMounted(() => {
  const initialTraces = buildTracesFromAgents(agents.value)
  Plotly.newPlot(chart.value, initialTraces, baseLayout, {
    displayModeBar: false,
    responsive: true,
    staticPlot: false,
  })

  // Initialize indices and last lengths
  const indexMap = new Map()
  const lenMap = new Map()
  initialTraces.forEach((t, i) => {
    const id = (agents.value[i]?.id ?? t.uid ?? `trace-${i}`)
    indexMap.set(id, i)
    lenMap.set(id, agents.value[i]?.x?.length ?? t.x?.length ?? 0)
  })
  traceIndexById.value = indexMap
  lastLenById.value = lenMap

  // Resize handling
  resizeObserver.value = new ResizeObserver(() => {
    if (chart.value) Plotly.Plots.resize(chart.value)
  })
  resizeObserver.value.observe(chart.value)
})

onBeforeUnmount(() => {
  resizeObserver.value?.disconnect()
  if (chart.value) Plotly.purge(chart.value)
})

// Streaming updates using extendTraces
watchEffect(() => {
  if (!chart.value) return

  const currAgents = agents.value
  const idSet = new Set(currAgents.map(a => a.id))

  // If no agents, clear the chart and reset state
  if (!currAgents.length) {
    // Reset plot to empty if needed
    if ((chart.value.data?.length ?? 0) > 0) {
      Plotly.react(chart.value, [], baseLayout, { displayModeBar: false, responsive: true })
    }
    traceIndexById.value = new Map()
    lastLenById.value = new Map()
    return
  }

  // If the Plotly graph has no traces yet but we do have agents, seed the plot
  const gdDataLen = chart.value?.data?.length ?? 0
  if (gdDataLen === 0 && currAgents.length > 0) {
    const seeded = buildTracesFromAgents(currAgents)
    Plotly.react(chart.value, seeded, baseLayout, { displayModeBar: false, responsive: true })

    // Build fresh maps based on current agents
    const indexMap0 = new Map()
    currAgents.forEach((a, i) => indexMap0.set(a.id, i))
    traceIndexById.value = indexMap0

    const lenMap0 = new Map()
    currAgents.forEach(a => lenMap0.set(a.id, a.x?.length ?? 0))
    lastLenById.value = lenMap0

    // Avoid extend/reflow in the same tick; next reactive run will handle streaming
    return
  }

  // 1) Remove traces whose agents disappeared
  const toDelete = []
  for (const [id, idx] of traceIndexById.value.entries()) {
    if (!idSet.has(id)) toDelete.push(idx)
  }
  if (toDelete.length) {
    // Delete in descending order to keep indices correct
    toDelete.sort((a, b) => b - a)
    Plotly.deleteTraces(chart.value, toDelete)

    // Rebuild index map to match actual chart data by uid if available; fallback to currAgents order
    const newIndexMap = new Map()
    const gd = chart.value
    if (gd?.data?.length) {
      gd.data.forEach((t, i) => {
        const uid = t.uid || t.name || currAgents[i]?.id
        if (uid) newIndexMap.set(uid, i)
      })
    }
    // Ensure all current agents have an entry
    currAgents.forEach((a, i) => {
      if (!newIndexMap.has(a.id)) newIndexMap.set(a.id, i)
    })
    traceIndexById.value = newIndexMap

    // Rebuild lastLen map (cap to current lengths)
    const newLenMap = new Map()
    currAgents.forEach(a => {
      const prev = lastLenById.value.get(a.id) ?? (a.x?.length ?? 0)
      newLenMap.set(a.id, Math.min(prev, a.x?.length ?? 0))
    })
    lastLenById.value = newLenMap
  }

  // 2) Add any new agents
  const addTraces = []
  const addIds = []
  currAgents.forEach((a, i) => {
    if (!traceIndexById.value.has(a.id)) {
      const xArr = [...(a.x ?? [])]
      const yArr = [...(a.y ?? [])]
      const hasData = xArr.length > 0 && yArr.length > 0
      addTraces.push({
        uid: a.id,
        name: a.id,
        type: 'scatter',
        mode: 'lines',
        line: { color: colorForIndex(i), width: 2 },
        x: hasData ? xArr : [0],
        y: hasData ? yArr : [null],
        visible: hasData ? true : 'legendonly',
      })
      addIds.push(a.id)
    }
  })
  if (addTraces.length) {
    Plotly.addTraces(chart.value, addTraces)
    // Compute indices of newly appended traces
    const startIdx = chart.value.data.length - addTraces.length
    addIds.forEach((id, k) => {
      traceIndexById.value.set(id, startIdx + k)
      const a = currAgents.find(x => x.id === id)
      lastLenById.value.set(id, a?.x?.length ?? 0)
    })
  }

  // 3) Prepare extend/rewrite operations
  const extendXs = []
  const extendYs = []
  const extendIndices = []

  const resetOps = [] // { index, x, y, id }

  currAgents.forEach((a) => {
    const id = a.id
    const idx = traceIndexById.value.get(id)
    if (idx == null) return

    const xArr = a.x ?? []
    const yArr = a.y ?? []
    const prevLen = lastLenById.value.get(id) ?? 0
    const currLen = xArr.length

    // Detect data reset or time going backwards
    const lengthShrank = currLen < prevLen
    const wentBackwards = prevLen > 0 && currLen > 0 && xArr[Math.min(prevLen, currLen) - 1] > xArr[currLen - 1]

    if (lengthShrank || wentBackwards) {
      resetOps.push({ index: idx, x: [...xArr], y: [...yArr], id })
      return
    }

    if (currLen > prevLen) {
      extendXs.push(xArr.slice(prevLen))
      extendYs.push(yArr.slice(prevLen))
      extendIndices.push(idx)
    }
  })

  // 3a) Apply full restyles for traces that reset
  if (resetOps.length) {
    // filter to valid indices present in the current graph
    const maxIdx = (chart.value.data?.length ?? 0) - 1
    const validOps = resetOps.filter(op => Number.isInteger(op.index) && op.index >= 0 && op.index <= maxIdx)
    if (validOps.length) {
      const indices = validOps.map(op => op.index)
      const xs = validOps.map(op => op.x)
      const ys = validOps.map(op => op.y)
      Plotly.restyle(chart.value, { x: xs, y: ys }, indices)

      // Update last lengths
      validOps.forEach(op => {
        // Find the agent by id (safer than reading via index after restyle)
        const a = currAgents.find(x => x.id === op.id)
        lastLenById.value.set(op.id, a?.x?.length ?? op.x.length)
      })
    }
  }

  // 3b) Append new points via extendTraces
  if (extendIndices.length) {
    // Only use indices that exist in the current gd.data
    const maxIdx2 = (chart.value.data?.length ?? 0) - 1
    const validIdx = extendIndices.filter(i => Number.isInteger(i) && i >= 0 && i <= maxIdx2)
    const idxMap = new Map(validIdx.map((i, k) => [i, k]))
    const xsValid = validIdx.map(i => extendXs[idxMap.get(i)])
    const ysValid = validIdx.map(i => extendYs[idxMap.get(i)])

    if (validIdx.length) {
      Plotly.extendTraces(
        chart.value,
        { x: xsValid, y: ysValid },
        validIdx,
      )
    }
    // Update last lengths for extended traces
    currAgents.forEach((a) => {
      const idx = traceIndexById.value.get(a.id)
      if (validIdx.includes(idx)) {
        lastLenById.value.set(a.id, a.x.length)
      }
    })
  }

  // 4) Update axes based on current data
  const lastXs = currAgents.map(a => (a.x?.length ? a.x[a.x.length - 1] : 0))
  const allYs = currAgents.flatMap(a => a.y ?? [])
  const maxXRaw = lastXs.length ? Math.max(...lastXs) : 0
  const maxYRaw = allYs.length ? Math.max(...allYs) : 1
  const maxX = Math.ceil(maxXRaw / props.xAxisStep) * props.xAxisStep
  const maxY = Math.ceil(maxYRaw / props.yAxisStep) * props.yAxisStep

  Plotly.relayout(chart.value, {
    'xaxis.range': [0, Math.max(500, maxX)],
    'yaxis.range': [0, Math.max(10, maxY)],
  })
})
</script>

<template>
  <div class="instrumentation real-time">
    <div ref="chart" class="chart-container"></div>
    <p>agent data version ({{ dataVersion }})</p>
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
