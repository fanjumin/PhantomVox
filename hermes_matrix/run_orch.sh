#!/bin/bash
cd /home/guxiao/projects/video_ai_agent/hermes_matrix

# Read .env and export its vars
set -a
source .env
set +a

# Use DeepSeek official API if available, else fall back to SiliconFlow
if [ -z "$DEEPSEEK_API_KEY" ] && [ -n "$SILICONFLOW_KEY" ]; then
  export DEEPSEEK_API_KEY="$SILICONFLOW_KEY"
  export DEEPSEEK_BASE_URL="https://api.siliconflow.cn/v1"
fi

# Feed APPROVEs for all interactive prompts.
# Per-round counts: Round1=5, Rounds2-4=3 each, Save=1. Total max=15.
printf 'APPROVE\n%.0s' {1..15} | python3 orchestrator.py
