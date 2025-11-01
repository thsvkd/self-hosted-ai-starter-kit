#!/bin/bash

docker compose --profile gpu-nvidia pull
docker compose --profile gpu-nvidia up -d 