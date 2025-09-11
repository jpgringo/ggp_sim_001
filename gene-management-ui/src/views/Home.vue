<template>
  <main class="home">
    <SimControls
        :on-start-scenario="handleStartScenario"
        :on-stop-scenario="handleStopScenario"
        :on-panic="handlePanic"
    ></SimControls>
    <SimInstrumentPanel></SimInstrumentPanel>
  </main>
</template>

<script setup>
import { customAlphabet } from "nanoid";
import SimControls from "../components/SimControls.vue";
import api_connector from "@/scripts/api_connector.js";
import {useSimStore} from "../../stores/simStore.js";
import SimInstrumentPanel from "@/components/SimInstrumentPanel.vue";
const simStore = useSimStore()

// Crockford Base32 alphabet (no I, L, O, U)
const crockfordBase32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
const nanoid = customAlphabet(crockfordBase32, 8)

const handleStartScenario = async (opts) => {
  const scenarioId = nanoid()
  console.log(`Home.handleScenarioStart - scenarioId='${scenarioId}'; opts:`, opts);
  opts.unique_id = scenarioId;
  let result = await api_connector.startScenario(opts, [onSimMessage]);
  // if(result?.ok) {
  //   simStore.scenarioStarted(opts.scenario, opts.unique_id);
  // }
  console.log(`Home.handleSimStart - result:`, result);
};

const handleStopScenario = async (scenario) => {
  console.log(`handleStopScenario:`, scenario);
  let result = await api_connector.stopScenario(scenario);
  // if(result?.ok) {
  //   simStore.scenarioStarted(opts.scenario, opts.unique_id);
  // }
  // console.log(`Home.handleSimStart - result:`, result);
};

const handlePanic = async () => {
  console.log(`handlePanic:`);
  let result = await api_connector.panic();
  // if(result?.ok) {
  //   simStore.scenarioStarted(opts.scenario, opts.unique_id);
  // }
  // console.log(`Home.handleSimStart - result:`, result);
};

const onSimMessage = (msg) => {
  console.log(`Home got sim message:`, msg);
  switch(msg?.type) {
    case "start":
      simStore.scenarioStarted(msg.data)
      break;
    case "stop":
      simStore.scenarioStopped(msg);
      break;
  }
}

</script>
