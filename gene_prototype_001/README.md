# GenePrototype0001

**GenePrototype0001** is an Elixir application designed to serve as a prototype for handling external connections via UDP and JSON-RPC.

## Structure

- **ExternalConnectionSupervisor**: Top-level supervisor responsible for starting and monitoring connection-related processes.
- **UdpConnectionServer**: GenServer that listens on a configurable UDP port and logs all incoming messages to the console. Future versions will support sending messages and JSON-RPC handling.

## Configuration

The UDP port can be configured in `config/config.exs`:

```elixir
config :gene_prototype_0001,
  udp_port: 4000
```

## Running

To start the application:

```sh
mix run --no-halt
```

## Extending

- Add more GenServers under `ExternalConnectionSupervisor` for other protocols or connections.
- Extend `UdpConnectionServer` to support sending UDP messages and JSON-RPC parsing.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gene_prototype_0001` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gene_prototype_0001, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gene_prototype_0001>.
