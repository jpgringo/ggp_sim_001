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
      <button @click="handlePanic" class="panic">Panic!</button>
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
  onStartScenario: {
    type: Function,
    required: true
  },
  onStopScenario: {
    type: Function,
    required: true
  },
  onPanic: {
    type: Function,
    required: true
  }
});


const handleStart = () => {
  if (props.onStartScenario) {
    props.onStartScenario({agents: parseInt(agentsInput.value.value), scenario: currentScenario.value});
  }
};

const handleStop = () => {
  if (props.onStopScenario) {
    props.onStopScenario(simStore.activeScenario);
  } else {
    console.error("No handler for stop scenario");
  }
};

const handlePanic = () => {
  if (props.onPanic) {
    props.onPanic();
  } else {
    console.error("No handler for panic");
  }
};


</script>
