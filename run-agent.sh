#!/bin/bash
AGENT=$1
TASK=$2

case $AGENT in
  architect)
    claude_code --system-prompt docs/agent-prompts/architect.md \
                --task "$TASK"
    ;;
  scrum)
    claude_code --system-prompt docs/agent-prompts/scrum-master.md \
                --task "$TASK"
    ;;
  engineer)
    claude_code --system-prompt docs/agent-prompts/engineer.md \
                --task "$TASK" \
                --max-iterations 50
    ;;
  qa)
    claude_code --system-prompt docs/agent-prompts/qa.md \
                --task "$TASK"
    ;;
esac
