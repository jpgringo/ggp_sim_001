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
    scenarioStarted(scenario, id) {
      console.log(`simStore.scenarioStarted - scenario = ${scenario}; id=${id}`);
      this.activeScenario = {scenario: scenario, id: id};
    },
    scenarioStopped(id) {
      this.activeScenario = undefined;
    }
  },
})
