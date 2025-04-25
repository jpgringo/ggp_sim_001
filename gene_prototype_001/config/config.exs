# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
import Config

config :gene_prototype_0001,
  receive_port: 7400,
  send_ip: "127.0.0.1",
  send_port: 7401

config :logger,
  level: :info,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
