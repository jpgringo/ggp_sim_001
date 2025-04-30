<script setup>
import SystemStatus from './components/SystemStatus.vue'
import Home from "./views/Home.vue";
</script>

<template>
  <header>
    <h1>Gene Manager</h1>
    <SystemStatus/>
  </header>
  <Home></Home>
</template>
