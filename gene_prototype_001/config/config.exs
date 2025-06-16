# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :gene_prototype_0001,
  send_ip: "127.0.0.1",
  receive_port: 7400,
  send_port: 7401,
  direct_log_level: :info

config :logger,
  level: :warning,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Bandit server configuration; 4000 is alreay the Bandit default
config :bandit,
  port: 4000,
    # Reduce connection pool size
  thousand_island: [
    pool_size: 4,  # Default is 100
    max_connections: 16  # Default is 16384
  ]
