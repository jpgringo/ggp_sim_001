<script setup>
import { ref, onMounted, onBeforeUnmount, watchEffect, computed } from 'vue'
import Plotly from 'plotly.js-dist-min'
import {useSimStore} from "../../stores/simStore.js";
import chroma from 'chroma-js'

const simStore = useSimStore()

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

const series = computed(() => props.agentData?.series ?? [])

// Use a Brewer color scale from chroma-js for trace colors
// Other options are Accent, Viridis, Spectral, Dark2, Paired, etc. See https://www.vis4.net/chromajs/#chroma-brewer
// We generate colors on demand to support any number of series
const palette = chroma.scale('Spectral').mode('lrgb')
const colorForIndex = (i) => {
  // Map discrete index to a position in [0,1] with golden ratio spacing to avoid early repeats
  const phi = (Math.sqrt(5) - 1) / 2 // ~0.6180339887
  const t = (i * phi) % 1
  return palette(t).hex()
}

function buildTracesFromAgents(currSeries) {
  return currSeries.map((d, i) => {
    const rawX = [...(d.x ?? [])]
    const xArr = scaleXArray(rawX)
    const yArr = [...(d.y ?? [])]
    const hasData = xArr.length > 0 && yArr.length > 0
    const dashValue = (i % 2 === 0) ? 'solid' : 'dash'
    const opacityValue = (i % 2 === 0) ? 1 : 0.5
    return {
      uid: d.id ?? `trace-${i}`,
      name: d.id ?? `Trace ${i + 1}`,
      type: 'scatter',
      mode: 'lines',
      line: { color: colorForIndex(Math.floor(i/2)), width: 2, dash: dashValue },
      opacity: opacityValue,
      x: hasData ? xArr : [0],
      y: hasData ? yArr : [null],
      // Show in legend even if there is no data yet
      visible: hasData ? true : 'legendonly',
    }
  })
}

const baseLayout = {
  xaxis: { range: [0, 500], title: { text: 'Time (ms)' } },
  yaxis: { range: [0, 10], title: { text: 'Event Count' } },
  height: 400,
  margin: { t: 20, l: 60, r: 40, b: 40 },
  showlegend: true,
}

// Track the current time unit for the x-axis: 'ms' | 's' | 'min'
const TimeUnit = Object.freeze({ ms: 'ms', s: 's', min: 'min' })
const xTimeUnit = ref(TimeUnit.ms)

function scaleFactorForUnit(unit) {
  switch (unit) {
    case TimeUnit.s: return 1000
    case TimeUnit.min: return 60000
    default: return 1
  }
}

function scaleXArray(xs) {
  if (!Array.isArray(xs)) return xs
  const denom = scaleFactorForUnit(xTimeUnit.value)
  return denom === 1 ? xs : xs.map(v => (v != null ? v / denom : v))
}

onMounted(() => {
  const initialTraces = buildTracesFromAgents(series.value)
  Plotly.newPlot(chart.value, initialTraces, baseLayout, {
    displayModeBar: false,
    responsive: true,
    staticPlot: false,
  })

  // Initialize indices and last lengths
  const indexMap = new Map()
  const lenMap = new Map()
  initialTraces.forEach((t, i) => {
    const id = (series.value[i]?.id ?? t.uid ?? `trace-${i}`)
    indexMap.set(id, i)
    lenMap.set(id, series.value[i]?.x?.length ?? t.x?.length ?? 0)
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

  const currSeries = series.value
  const idSet = new Set(currSeries.map(a => a.id))

  // If no series, clear the chart and reset state
  if (!currSeries.length) {
    // Reset plot to empty if needed
    if ((chart.value.data?.length ?? 0) > 0) {
      Plotly.react(chart.value, [], baseLayout, { displayModeBar: false, responsive: true })
    }
    // Reset unit mode to default (ms) for a new plot
    xTimeUnit.value = TimeUnit.ms
    traceIndexById.value = new Map()
    lastLenById.value = new Map()
    return
  }

  // If the Plotly graph has no traces yet but we do have series, seed the plot
  const gdDataLen = chart.value?.data?.length ?? 0
  if (gdDataLen === 0 && currSeries.length > 0) {
    const seeded = buildTracesFromAgents(currSeries)
    Plotly.react(chart.value, seeded, baseLayout, { displayModeBar: false, responsive: true })

    // Build fresh maps based on current series
    const indexMap0 = new Map()
    currSeries.forEach((a, i) => indexMap0.set(a.id, i))
    traceIndexById.value = indexMap0

    const lenMap0 = new Map()
    currSeries.forEach(a => lenMap0.set(a.id, a.x?.length ?? 0))
    lastLenById.value = lenMap0

    // Avoid extend/reflow in the same tick; next reactive run will handle streaming
    return
  }

  // 1) Remove traces whose series disappeared
  const toDelete = []
  for (const [id, idx] of traceIndexById.value.entries()) {
    if (!idSet.has(id)) toDelete.push(idx)
  }
  if (toDelete.length) {
    // Delete in descending order to keep indices correct
    toDelete.sort((a, b) => b - a)
    Plotly.deleteTraces(chart.value, toDelete)

    // Rebuild index map to match actual chart data by uid if available; fallback to currSeries order
    const newIndexMap = new Map()
    const gd = chart.value
    if (gd?.data?.length) {
      gd.data.forEach((t, i) => {
        const uid = t.uid || t.name || currSeries[i]?.id
        if (uid) newIndexMap.set(uid, i)
      })
    }
    // Ensure all current series have an entry
    currSeries.forEach((a, i) => {
      if (!newIndexMap.has(a.id)) newIndexMap.set(a.id, i)
    })
    traceIndexById.value = newIndexMap

    // Rebuild lastLen map (cap to current lengths)
    const newLenMap = new Map()
    currSeries.forEach(a => {
      const prev = lastLenById.value.get(a.id) ?? (a.x?.length ?? 0)
      newLenMap.set(a.id, Math.min(prev, a.x?.length ?? 0))
    })
    lastLenById.value = newLenMap
  }

  // 2) Add any new series
  const addTraces = []
  const addIds = []
  currSeries.forEach((a, i) => {
    if (!traceIndexById.value.has(a.id)) {
      const xArr = scaleXArray([...(a.x ?? [])])
      const yArr = [...(a.y ?? [])]
      const hasData = xArr.length > 0 && yArr.length > 0
      const dashValue = (i % 2 === 0) ? 'solid' : 'dash'
      const opacityValue = (i % 2 === 0) ? 0.6 : 1
      addTraces.push({
        uid: a.id,
        name: a.id,
        type: 'scatter',
        mode: 'lines',
        line: { color: colorForIndex(Math.floor(i/2)), width: 2, dash: dashValue },
        opacity: opacityValue,
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
      const a = currSeries.find(x => x.id === id)
      lastLenById.value.set(id, a?.x?.length ?? 0)
    })
  }

  // 3) Prepare extend/rewrite operations
  const extendXs = []
  const extendYs = []
  const extendIndices = []

  const resetOps = [] // { index, x, y, id }

  currSeries.forEach((a) => {
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
      const xs = validOps.map(op => scaleXArray(op.x))
      const ys = validOps.map(op => op.y)
      Plotly.restyle(chart.value, { x: xs, y: ys }, indices)

      // Update last lengths
      validOps.forEach(op => {
        // Find the agent by id (safer than reading via index after restyle)
        const a = currSeries.find(x => x.id === op.id)
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
    const xsValid = validIdx.map(i => scaleXArray(extendXs[idxMap.get(i)]))
    const ysValid = validIdx.map(i => extendYs[idxMap.get(i)])

    if (validIdx.length) {
      Plotly.extendTraces(
        chart.value,
        { x: xsValid, y: ysValid },
        validIdx,
      )
    }
    // Update last lengths for extended traces
    currSeries.forEach((a) => {
      const idx = traceIndexById.value.get(a.id)
      if (validIdx.includes(idx)) {
        lastLenById.value.set(a.id, a.x.length)
      }
    })
  }

  // 4) Update axes based on current data
  const lastXs = currSeries.map(a => (a.x?.length ? a.x[a.x.length - 1] : 0))
  const allYs = currSeries.flatMap(a => a.y ?? [])
  const maxXRaw = lastXs.length ? Math.max(...lastXs) : 0
  const maxYRaw = allYs.length ? Math.max(...allYs) : 1
  const maxX = Math.ceil(maxXRaw / props.xAxisStep) * props.xAxisStep
  const maxY = Math.ceil(maxYRaw / props.yAxisStep) * props.yAxisStep

  // Decide units based on proposed upper bound in milliseconds
  const proposedUpperMs = Math.max(500, maxX)
  let newUnit = TimeUnit.ms
  if (proposedUpperMs >= 300000) newUnit = TimeUnit.min
  else if (proposedUpperMs >= 5000) newUnit = TimeUnit.s

  // If unit mode changes, restyle all X data to the new units
  if (newUnit !== xTimeUnit.value) {
    xTimeUnit.value = newUnit
    const allXs = currSeries.map(a => scaleXArray([...(a.x ?? [])]))
    const allYs = currSeries.map(a => [...(a.y ?? [])])
    const indices = allXs.map((_, i) => i)
    if (allXs.length) {
      Plotly.restyle(chart.value, { x: allXs, y: allYs }, indices)
    }
  }

  const denom = scaleFactorForUnit(xTimeUnit.value)
  const xUpper = proposedUpperMs / denom
  const xTitle = xTimeUnit.value === TimeUnit.ms ? 'Time (ms)'
                 : xTimeUnit.value === TimeUnit.s ? 'Time (s)'
                 : 'Time (mins)'

  // Choose tick step for minutes to allow 0.25 or 0.5 minute subdivisions as space permits
  const relayout = {
    'xaxis.range': [0, xUpper],
    'xaxis.title.text': xTitle,
    'yaxis.range': [0, Math.max(10, maxY)],
  }
  if (xTimeUnit.value === TimeUnit.min) {
    // Aim for about 6–10 ticks
    const targetTicks = 8
    const rawDt = xUpper / targetTicks
    // Snap to 0.25, 0.5, 1, 2, 5 minute steps
    const candidates = [0.25, 0.5, 1, 2, 5, 10, 15, 30]
    let dtick = candidates[0]
    for (const c of candidates) { if (c >= rawDt) { dtick = c; break } }
    relayout['xaxis.dtick'] = dtick
    relayout['xaxis.tickformat'] = '~r'
  } else {
    // Clear any minute-specific tick settings when not in minutes
    relayout['xaxis.dtick'] = null
    relayout['xaxis.tickformat'] = null
  }

  Plotly.relayout(chart.value, relayout)
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
