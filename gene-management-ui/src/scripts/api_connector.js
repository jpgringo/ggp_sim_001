
export default {
  startSim: async (options) => {
    const response = await fetch('/api/simulation', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(options)
    });
    return response.json();
  },
  stopSim: async (options) => {
    const response = await fetch('/api/simulation/stop', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(options)
    });
    return response.json();
  }
}
