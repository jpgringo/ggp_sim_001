<script setup>
import {onMounted} from 'vue';
import {useSimStore} from "../../stores/simStore.js";
import SimRealTimeInstrumentation from "@/components/SimRealTimeInstrumentation.vue";
const simStore = useSimStore()

const dummyAgentTraces = [
  { name: 'Agent 1 - sensors', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#FF1919', width: 2 } },
  { name: 'Agent 2', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#19FF19', width: 2 } },
  { name: 'Agent 3', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#1919FF', width: 2 } },
  { name: 'Agent 4', x: [], y: [], type: 'scatter', mode: 'lines', line: { color: '#FFB619', width: 2 } }
]

const populateDummyTraces = () => {
  const maxInterval = 50
  const maxPoints = 10
  dummyAgentTraces.forEach(trace => {
    // trace.x = new Array(maxPoints).fill(0)
    // trace.y = new Array(maxPoints).fill(0)
    let lastX = 0
    trace.x.push(0)
    trace.y.push(0)
    for (let i = 0; i < maxPoints; i++) {
      let interval = Math.floor(Math.random() * maxInterval)
      lastX += interval
      trace.x.push(lastX)
      trace.y.push(Math.floor(Math.random() * 8))
    }
  })

}

populateDummyTraces()

onMounted( () => {
  console.log(`SimInstrumentPanel is mounting!!`, dummyAgentTraces);
})

</script>

<template>
  <div>This is the sim instrument panel</div>
  <p>Running? {{simStore.running}}</p>
  <p>Active scenario: {{simStore.activeScenario}}</p>
  <SimRealTimeInstrumentation
      :agent-traces="dummyAgentTraces"
  ></SimRealTimeInstrumentation>
</template>

