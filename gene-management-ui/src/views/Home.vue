<template>
  <main class="home">
    <SimControls :on-start-sim="handleSimStart"></SimControls>
    <SimInstrumentPanel></SimInstrumentPanel>
  </main>
</template>

<script setup>
import SimControls from "../components/SimControls.vue";
import api_connector from "@/scripts/api_connector.js";
import {useSimStore} from "../../stores/simStore.js";
import SimInstrumentPanel from "@/components/SimInstrumentPanel.vue";
const simStore = useSimStore()

const handleSimStart = async (opts) => {
  console.log(`Home.handleSimStart - opts:`, opts);
  let result = await api_connector.startSim(opts, [onSimMessage]);
  if(result?.ok) {
    simStore.scenarioStarted(opts.scenario);
  }
  console.log(`Home.handleSimStart - result:`, result);
};

const onSimMessage = (msg) => {
  console.log(`Home got sim message:`, msg);
  switch(msg?.type) {
    case "stop":
      simStore.scenarioStopped(msg);
  }
}

</script>
