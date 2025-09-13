<script setup>
import {onMounted, reactive, watch} from 'vue';
import {useSimStore} from "../../stores/simStore.js";
import SimRealTimeInstrumentation from "@/components/SimRealTimeInstrumentation.vue";

const simStore = useSimStore()

const agentData = reactive({
  version: 0,
  agents: [
    {id: "12345", x: [0], y: [0]},
    {id: "23456", x: [0], y: [0]}
  ]
})

const addSampleAgentData = (newPointCount) => {
  const maxInterval = 50
  const maxPoints = 10
  newPointCount = newPointCount === undefined ? maxPoints : newPointCount
  agentData.agents.forEach(agent => {

    console.log(`adding point to `, agent);
    let lastX = agent.x.length > 0 ? agent.x[agent.x.length - 1] : 0
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

onMounted(() => {
  console.log(`SimInstrumentPanel is mounting!!`, agentData);
})

// Watch for changes to activeScenario, particularly nullish <-> value transitions
function onScenarioActivated(scenario) {
  console.log('[SimInstrumentPanel] Scenario activated:', scenario)
  initializeAgentData(scenario)
  // Placeholder: initialize instrumentation data, subscriptions, etc.
}

function onScenarioDeactivated(prevScenario) {
  console.log('[SimInstrumentPanel] Scenario deactivated. Previous scenario:', prevScenario)
  // Placeholder: cleanup instrumentation data, timers, subscriptions, etc.
}

function onScenarioChanged(newScenario, oldScenario) {
  console.log('[SimInstrumentPanel] Scenario changed:', {newScenario, oldScenario})
  // Placeholder: handle scenario switch without going through null
}

function initializeAgentData(scenario) {
  agentData.agents = scenario.agents.map(agent => ({id: agent.id, x: [0], y: [0]}))
  agentData.version = 0
}

function loadSampleScenario() {
  const sampleScenario = {
    "id": "292Z27D8",
    "name": "map_0003.json_292Z27D8",
    "agents": [
      {
        "actuators": 1,
        "id": "6939845068186"
      },
      {
        "actuators": 1,
        "id": "6939845068187"
      }
    ],
    "scenario_name": "map_0003.json"
  }
  onScenarioActivated(sampleScenario)
}

watch(
    () => simStore.activeScenario,
    (newVal, oldVal) => {
      const wasNullish = oldVal == null
      const isNullish = newVal == null

      if (wasNullish && !isNullish) {
        onScenarioActivated(newVal)
      } else if (!wasNullish && isNullish) {
        onScenarioDeactivated(oldVal)
      } else if (!wasNullish && !isNullish && newVal !== oldVal) {
        onScenarioChanged(newVal, oldVal)
      }
    }
)

</script>

<template>
  <div>This is the sim instrument panel</div>
  <p>Running? {{ simStore.running }}</p>
  <p>Active scenario: {{ simStore.activeScenario }}</p>
  <SimRealTimeInstrumentation
      :agent-data="agentData"
  ></SimRealTimeInstrumentation>
  <p>
    <button @click="loadSampleScenario">Load Sample Scenario</button>
    <button @click="addPoints">Add Points</button>
  </p>
</template>

