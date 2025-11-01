#!/bin/bash

docker run --rm -it --network self-hosted-ai-starter-kit_demo cloudflare/cloudflared:latest tunnel --url http://n8n:5678