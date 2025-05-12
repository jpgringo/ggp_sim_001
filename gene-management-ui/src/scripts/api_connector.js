export default {
  startSim: async (options, messageHandlers) => {
    const response = await fetch('/api/simulation', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(options)
    });

    if (response.ok) {
      const wsPath = response.headers.get('x-simulation-ws');
      if (wsPath) {
        const wsUrl = `ws://${window.location.host}${wsPath}`;
        const ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          console.log('WebSocket connection established');
        };

        ws.onmessage = (event) => {
          const message = JSON.parse(event.data);
          if (message.type === 'batch') {
            console.log('Received batch:', message.data);
          }
          messageHandlers && messageHandlers.forEach(handler => handler(message));
        };

        ws.onclose = () => {
          console.log('WebSocket connection closed');
        };

        return { ok: true, websocket: ws };
      }
    }

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
