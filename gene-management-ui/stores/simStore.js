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
    scenarioStarted(data) {
      console.log(`simStore.scenarioStarted - scenario = ${data.scenario_name}; id=${data.id}`);
      console.log(`this: `, this);
      this.activeScenario = data;
      this.running = true;
    },
    scenarioStopped(id) {
      this.activeScenario = undefined;
      this.running = false
    }
  },
})
