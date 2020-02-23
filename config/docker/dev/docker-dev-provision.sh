#!/bin/bash
mix ecto.create
mix ecto.migrate
mix run apps/snitch_core/priv/repo/seed/seeds.exs
iex -S mix phx.server
