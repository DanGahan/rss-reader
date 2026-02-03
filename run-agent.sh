#!/bin/bash

# Default values
MODE="claude"
AGENT=""
TASK=""

# Parse flags (e.g., ./run-agent.sh -m gemini qa "task")
while getopts "m:" opt; do
  case $opt in
    m) MODE="$OPTARG" ;; # Fixed: Use OPTARG for getopts
    *) echo "Invalid option"; exit 1 ;;
  esac
done
shift $((OPTIND -1))

AGENT=$1
shift
TASK="$*"

if [ -z "$AGENT" ]; then
    echo "Usage: ./run-agent.sh [-m claude|gemini] <agent> [initial task]"
    echo "  Agents: architect, scrum, engineer, qa, devops"
    exit 1
fi

# Map Agent to Prompt File
case $AGENT in
  architect) PROMPT_FILE="docs/agent-prompts/architect.md" ;;
  scrum)     PROMPT_FILE="docs/agent-prompts/scrum-master.md" ;;
  engineer)  PROMPT_FILE="docs/agent-prompts/engineer.md" ;;
  qa)        PROMPT_FILE="docs/agent-prompts/qa.md" ;;
  devops)    PROMPT_FILE="docs/agent-prompts/devops.md" ;;
  *) echo "Unknown agent: $AGENT"; exit 1 ;;
esac

# Check for prompt file
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: Prompt file not found at $PROMPT_FILE"
    exit 1
fi

if [ "$MODE" == "gemini" ]; then
    echo "--- Starting Interactive Gemini Session ($AGENT) ---"
    
    # 1. Use GEMINI_SYSTEM_MD to lock in the agent's persona
    # 2. Use -i to pass the initial task and STAY in the shell
    # 3. Use --yolo so it doesn't prompt for permission on basic git/ls commands
    GEMINI_SYSTEM_MD="$PROMPT_FILE" gemini --yolo -i "$TASK"

else
    echo "--- Starting Interactive Claude Session ($AGENT) ---"
    # Claude Code is interactive by default. 
    # We pass the prompt file and the initial task.
    claude --system-prompt-file "$PROMPT_FILE" "$TASK"
fi
