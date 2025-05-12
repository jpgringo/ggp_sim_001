<template>
  <div class="sim-controls">
    <form @submit.prevent="false">
      <fieldset>
        <label>Agents <input ref="agentsInput" name="agents" type="number" min="1" max="4" value="1"></label>
        <label>Scenarios <select ref="scenariosInput" name="scenarios" v-model="currentScenario">
          <option v-for="scenario in simStore.scenarios" :key="scenario" :value="scenario">{{ scenario }}</option>
        </select></label>
      </fieldset>
      <button @click="handleStart">Start</button>
      <button @click="handleStop">Stop</button>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import api_connector from "../scripts/api_connector.js";
import {useSimStore} from "../../stores/simStore.js";
const agentsInput = ref(null);
const simStore = useSimStore();
const currentScenario = ref(simStore.scenarios[0]);

const props = defineProps({
  onStartSim: {
    type: Function,
    required: false
  }
});


const handleStart = () => {
  if (props.onStartSim) {
    props.onStartSim({agents: parseInt(agentsInput.value.value), scenario: currentScenario.value});
  }
};

const handleStop = () => {
  console.log('stopping sim...');
  api_connector.stopSim();
};
</script>
