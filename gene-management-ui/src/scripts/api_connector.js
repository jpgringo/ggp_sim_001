export default {
  startScenario: async (options, messageHandlers) => {
    const response = await fetch('/api/scenario', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(options)
    });

    if (response.ok) {
      const wsPath = response.headers.get('x-scenario-ws');
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

    return response;
  },

  stopScenario: async (scenario) => {
    console.log(`api_connector.stopScenario - scenario:`, scenario);
    let response
    try {
      response = await fetch(`/api/scenario/${scenario?.id || "NO_SCENARIO" }/stop`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(scenario)
      });
    } catch (error) {
      console.error(error);
      return error.response;
    }
    if(!response?.ok) {
      console.error('Could not stop scenario.:', response);
    }
    return response.json();
  },
  panic: async () => {
    console.log(`api_connector.panic`);
    let response;
    try {
      response = await fetch(`/api/scenario/panic`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        }
      });
    } catch (error) {
      console.error(error);
      return error;
    }
    if(!response.ok) {
      console.error('Panic failed.:', response);
    }
    return response;
  },
}
