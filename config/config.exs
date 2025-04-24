# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :gene_prototype_0001,
  udp_port: 7400

config :logger,
  level: :info,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
