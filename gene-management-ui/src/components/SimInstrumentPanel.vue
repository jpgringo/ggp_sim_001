<script setup>
import {useSimStore} from "../../stores/simStore.js";
const simStore = useSimStore()

</script>

<template>
  <div>This is the sim instrument panel</div>
  <p>Running? {{simStore.running}}</p>
  <p>Active scenario: {{simStore.activeScenario}}</p>
</template>

