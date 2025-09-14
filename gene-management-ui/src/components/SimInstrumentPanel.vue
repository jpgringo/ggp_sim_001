<script setup>
import {onMounted, reactive, watch} from 'vue';
import {useSimStore} from "../../stores/simStore.js";
import SimRealTimeInstrumentation from "@/components/SimRealTimeInstrumentation.vue";

const simStore = useSimStore()

function addPoints() {
  simStore.addSampleAgentData(1)
}

onMounted(() => {
  console.log(`SimInstrumentPanel is mounting!!`, simStore.agentData);
})

function onScenarioDeactivated(prevScenario) {
  console.log('[SimInstrumentPanel] Scenario deactivated. Previous scenario:', prevScenario)
  // Placeholder: cleanup instrumentation data, timers, subscriptions, etc.
}

function onScenarioChanged(newScenario, oldScenario) {
  console.log('[SimInstrumentPanel] Scenario changed:', {newScenario, oldScenario})
  // Placeholder: handle scenario switch without going through null
}

function loadSampleScenario() {
  const sampleScenario = {
    "id": "KJZQQG52",
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
  simStore.scenarioStarted(sampleScenario)
}

let lastElapsedTime = 0
function addSampleActuatorData() {
  const runId = "KJZQQG52"
  const rawId = ["6939845068186", "6939845068187"][Math.floor(Math.random() * 2)]
  const maxInterval = 50
  lastElapsedTime = lastElapsedTime + Math.ceil(Math.random() * maxInterval)
  const data =
      {
        "run_id": runId,
        "available_actuators": 1,
        "actuators_issued": Math.ceil(Math.random() * 17),
        "raw_id": rawId,
        "agent_id": `${runId}_${rawId}`,
        "sensor_data_received": Math.ceil(Math.random() * 50),
        "elapsed_time": lastElapsedTime
      }
  simStore.actuatorSent(data)
}

watch(
    () => simStore.activeScenario,
    (newVal, oldVal) => {
      const wasNullish = oldVal == null
      const isNullish = newVal == null

      if (wasNullish && !isNullish) {
        // onScenarioActivated(newVal)
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
      :agent-data="simStore.agentData"
  ></SimRealTimeInstrumentation>
  <p>
    <button @click="loadSampleScenario">Load Sample Scenario</button>
    <button @click="addPoints">Add Points</button>
    <button @click="addSampleActuatorData">Add Sample Actuator Data</button>
  </p>
</template>

