#!/bin/sh

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets
npm run deploy --prefix ./assets
mix phx.digest

# Custom tasks (like DB migrations)

# And then run the server like so:
# MIX_ENV=prod mix phx.server

