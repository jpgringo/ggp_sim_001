<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import {useSimStore} from "../../stores/simStore.js";

const status = ref('Checking...')
const checkInterval = ref(null)
const HEARTBEAT = 5000
const simStore = useSimStore()

const checkStatus = async () => {
  const systemDownResponse = {server: false, sim: false };
  try {
    const response = await fetch('/api/status')
    const data = await response.json()
    status.value = response.ok ? data : systemDownResponse
    console.log(`data:`, data);
    simStore.updateSimState(data.sim)
  } catch (error) {
    status.value = systemDownResponse
    console.error(error)
  }
  console.log(`status:`, status.value);
}

onMounted(() => {
  checkStatus() // Initial check
  checkInterval.value = setInterval(checkStatus, HEARTBEAT)
})

onUnmounted(() => {
  if (checkInterval.value) {
    clearInterval(checkInterval.value)
  }
})
</script>

<template>
  <div class="system-status">
    <span class="component-status" :class="{ 'ok': status.server }">server</span>
    <span class="component-status" :class="{ 'ok': simStore.running }">sim</span>
  </div>
</template>

<style scoped>
.system-status {
  padding: 8px;
}
</style>
