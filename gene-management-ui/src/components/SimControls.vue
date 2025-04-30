<template>
  <div class="sim-controls">
    <form @submit.prevent="handleStart">
      <fieldset>
        <label>Agents <input ref="agentsInput" name="agents" type="number" min="1" max="4" value="1"></label>
      </fieldset>
      <button type="submit">Start</button>
    </form>
  </div>
</template>

<script setup>
  import { ref } from 'vue';
  import api_connector from "../scripts/api_connector.js";

  const agentsInput = ref(null);

  const handleStart = () => {
    api_connector.startSim({ agents: parseInt(agentsInput.value.value) });
  };
</script>
