<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const status = ref('Checking...')
const checkInterval = ref(null)
const HEARTBEAT = 2000

const checkStatus = async () => {
  const systemDownResponse = {server: false, sim: false };
  try {
    const response = await fetch('/api/status')
    const data = await response.json()
    status.value = response.ok ? data : systemDownResponse
  } catch (error) {
    status.value = systemDownResponse
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
    {{ status }}
  </div>
</template>

<style scoped>
.system-status {
  padding: 8px;
}
</style>
