import {defineStore} from 'pinia';

export const useSimStore = defineStore('sim', {
  state: () => ({ running: true, scenarios: [], activeScenario: undefined }),
  getters: {
    currentlyRunning: (state) => state.running,
  },
  actions: {
    updateRunning(isRunning) {
      this.running = isRunning;
    },
    updateSimState(data) {
      this.running = data.ready
      this.scenarios = data.scenarios;
    },
    scenarioStarted(id) {
      this.activeScenario = {id: id};
    },
    scenarioStopped(id) {
      this.activeScenario = undefined;
    }
  },
})
