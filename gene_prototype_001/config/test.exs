# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :gene_prototype_0001,
  direct_log_level: :none
#  receive_port: 7400,
#  send_ip: "127.0.0.1",
#  send_port: 7401,
#
config :logger,
  level: :error,
  backends: [:console]

config :kernel, :logger_level, :error
#  handle_otp_reports: true,
#  handle_sasl_reports: true
#
#config :logger, :console,
#  format: "$time $metadata[$level] $message\n",
#  metadata: [:request_id]
#
## Bandit server configuration; 4000 is alreay the Bandit default
#config :bandit,
#  startup_log: false,
#  port: 4000,
#    # Reduce connection pool size
#  thousand_island: [
#    startup_log: false,
#    pool_size: 4,  # Default is 100
#    max_connections: 16,  # Default is 16384
#    logger_level: :error
#  ]
#
#config :logger,
#       level: :error,
#       backends: []
