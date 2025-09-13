<script setup>
import {onMounted, reactive} from 'vue';
import {useSimStore} from "../../stores/simStore.js";
import SimRealTimeInstrumentation from "@/components/SimRealTimeInstrumentation.vue";
const simStore = useSimStore()

const agentData = reactive({
  version: 0,
  agents: [
    { id: "12345", x:[0], y:[0]},
    { id: "23456", x:[0], y:[0]}
  ]
})

const addSampleAgentData = (newPointCount) => {
  const maxInterval = 50
  const maxPoints = 10
  newPointCount = newPointCount === undefined ? maxPoints : newPointCount
  agentData.agents.forEach(agent => {

    console.log(`adding point to `, agent);
    let lastX = agent.x.length > 0 ? agent.x[agent.x.length -1] : 0
    for (let i = 0; i < newPointCount; i++) {
      let interval = Math.floor(Math.random() * maxInterval)
      lastX += interval
      agent.x.push(lastX)
      agent.y.push(Math.floor(Math.random() * 8))
    }
  })
  agentData.version++
}

function addPoints() {
  addSampleAgentData(1)
}

addSampleAgentData()

onMounted( () => {
  console.log(`SimInstrumentPanel is mounting!!`, agentData);
})

</script>

<template>
  <div>This is the sim instrument panel</div>
  <p>Running? {{simStore.running}}</p>
  <p>Active scenario: {{simStore.activeScenario}}</p>
  <SimRealTimeInstrumentation
      :agent-data="agentData"
  ></SimRealTimeInstrumentation>
  <p><button @click="addPoints">Add Points</button></p>
</template>

