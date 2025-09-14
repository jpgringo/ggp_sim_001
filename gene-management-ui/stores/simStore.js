import {defineStore} from 'pinia';

function initializeAgentData(state, scenario) {
  state.agentData.series = []
  scenario.agents.forEach(agent => {
    state.agentData.series.push({id: agent.id, x: [0], y: [0]})
    state.agentData.series.push({id: agent.id + "_s", x: [0], y: [0]})
  })
  state.agentData.version = 0
}


export const useSimStore = defineStore('sim', {
  state: () => ({
    running: true,
    scenarios: [],
    activeScenario: undefined,
    agentData: {
      version: 0,
      agents: []
    }
  }),
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
      initializeAgentData(this, data)
      this.running = true;
    },
    scenarioStopped(_id) {
      this.activeScenario = undefined;
      this.running = false
    },
    actuatorSent(data) {
      console.log(`simStore.actuatorSent:`, data);
      const activeId = this.activeScenario?.id
      const dataRunId = data?.run_id
      if(!activeId || String(dataRunId) !== String(activeId)) {
        console.warn(`actuatorSent: ID mismatch. data.run_id=`, dataRunId, `typeof=`, typeof dataRunId, `; activeScenario.id=`, activeId, `typeof=`, typeof activeId, `; full data:`, data);
        console.warn(`activeScenario:`, this.activeScenario);
        return
      }
      console.log(`scenario matches, will update agent data`);
      const matchingActuatorSeries = this.agentData.series.find(a => a.id === data.raw_id)
      const matchingSensorSeries = this.agentData.series.find(a => a.id === data.raw_id + "_s")
      console.log(`matchingActuatorSeries:`, matchingActuatorSeries);
      matchingActuatorSeries.x.push(data.elapsed_time)
      matchingActuatorSeries.y.push(data.actuators_issued)
      matchingSensorSeries.x.push(data.elapsed_time)
      matchingSensorSeries.y.push(data.sensor_data_received)
    },
    addSampleAgentData(newPointCount)  {
      const maxInterval = 50
      const maxPoints = 10
      newPointCount = newPointCount === undefined ? maxPoints : newPointCount
      this.agentData.series.forEach(agent => {

        console.log(`adding point to `, agent);
        let lastX = agent.x.length > 0 ? agent.x[agent.x.length - 1] : 0
        for (let i = 0; i < newPointCount; i++) {
          let interval = Math.floor(Math.random() * maxInterval)
          lastX += interval
          agent.x.push(lastX)
          agent.y.push(Math.floor(Math.random() * 8))
        }
      })
      this.agentData.version++
    }

  },
})
