#!/bin/bash

AGENT=$1
shift
TASK="$*"

if [ -z "$AGENT" ] || [ -z "$TASK" ]; then
    echo "Usage: ./run-agent.sh <agent> <task>"
    echo "  e.g. ./run-agent.sh qa \"check open MRs and reviews\""
    echo "Agents: architect, scrum, engineer, qa, devops"
    exit 1
fi

# Build a comma-separated --allowedTools string from an array
build_tools() {
    local IFS=","
    echo "$*"
}

# Base read-only tools (all agents)
BASE_TOOLS=(
    "Read"
    "Glob"
    "Grep"
    "Bash(git status:*)"
    "Bash(git log:*)"
    "Bash(git diff:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(ls:*)"
    "Bash(cat:*)"
    "Bash(grep:*)"
    "Bash(find:*)"
    "Bash(head:*)"
    "Bash(tail:*)"
)

case $AGENT in
  architect)
    TOOLS=(
        "${BASE_TOOLS[@]}"
        "Write"
        "Edit"
        "Bash(mkdir:*)"
        "Bash(touch:*)"
    )
    PROMPT_FILE="docs/agent-prompts/architect.md"
    ;;
  scrum|scrum-master)
    TOOLS=(
        "${BASE_TOOLS[@]}"
        "Bash(gh issue:*)"
        "Bash(gh label:*)"
    )
    PROMPT_FILE="docs/agent-prompts/scrum-master.md"
    ;;
  engineer)
    TOOLS=(
        "${BASE_TOOLS[@]}"
        "Write"
        "Edit"
        "Bash(git checkout:*)"
        "Bash(git add:*)"
        "Bash(git commit:*)"
        "Bash(git push:*)"
        "Bash(gh pr create:*)"
        "Bash(gh pr list:*)"
        "Bash(gh pr view:*)"
        "Bash(xcodebuild:*)"
        "Bash(swift:*)"
        "Bash(swiftlint:*)"
        "Bash(mkdir:*)"
    )
    PROMPT_FILE="docs/agent-prompts/engineer.md"
    ;;
  qa)
    TOOLS=(
        "${BASE_TOOLS[@]}"
        "Bash(gh pr:*)"
        "Bash(gh run:*)"
        "Bash(xcodebuild:*)"
        "Bash(swift:*)"
        "Bash(swiftlint:*)"
    )
    PROMPT_FILE="docs/agent-prompts/qa.md"
    ;;
  devops)
    TOOLS=(
        "${BASE_TOOLS[@]}"
        "Write"
        "Edit"
        "Bash(git checkout:*)"
        "Bash(git add:*)"
        "Bash(git commit:*)"
        "Bash(git push:*)"
        "Bash(gh:*)"
        "Bash(xcodebuild:*)"
        "Bash(brew:*)"
        "Bash(mkdir:*)"
        "Bash(yamllint:*)"
    )
    PROMPT_FILE="docs/agent-prompts/devops.md"
    ;;
  *)
    echo "Unknown agent: $AGENT"
    echo "Available agents: architect, scrum, engineer, qa, devops"
    exit 1
    ;;
esac

ALLOWLIST=$(build_tools "${TOOLS[@]}")

claude -p \
    --allowedTools "$ALLOWLIST" \
    --system-prompt-file "$PROMPT_FILE" \
    "$TASK"
