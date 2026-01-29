#!/bin/bash

AGENT=$1
TASK=$2

if [ -z "$AGENT" ] || [ -z "$TASK" ]; then
    echo "Usage: ./run-agent.sh <agent> <task>"
    echo "Agents: architect, scrum, engineer, qa, devops"
    exit 1
fi

# Base safe commands (all agents)
BASE_SAFE=(
    "git status"
    "git log"
    "git diff"
    "git show"
    "git branch"
    "ls"
    "cat"
    "grep"
    "find"
    "head"
    "tail"
)

# Architect: Read-only + file creation
ARCHITECT_SAFE=(
    "${BASE_SAFE[@]}"
    "mkdir"
    "touch"
    "echo"
)

# Scrum Master: Git operations + GitHub CLI
SCRUM_SAFE=(
    "${BASE_SAFE[@]}"
    "gh issue create"
    "gh issue edit"
    "gh issue list"
    "gh issue view"
    "gh issue comment"
    "gh label create"
    "gh label edit"
    "gh label list"
)

# Engineer: Full development workflow
ENGINEER_SAFE=(
    "${BASE_SAFE[@]}"
    "git checkout -b"
    "git add"
    "git commit"
    "git push origin"
    "gh pr create"
    "gh pr list"
    "gh pr view"
    "xcodebuild build"
    "xcodebuild test"
    "swift build"
    "swift test"
    "swift package"
    "mkdir"
    "touch"
)

# QA: Read + test operations
QA_SAFE=(
    "${BASE_SAFE[@]}"
    "xcodebuild test"
    "swift test"
    "gh pr checkout"
    "gh pr review"
    "gh pr comment"
    "gh pr list"
)

# DevOps: Pipeline and workflow operations
DEVOPS_SAFE=(
    "${BASE_SAFE[@]}"
    "git checkout -b"
    "git add"
    "git commit"
    "git push origin"
    "gh workflow"
    "gh run"
    "gh secret"
    "gh pr create"
    "gh pr list"
    "gh api"
    "xcodebuild -showsdks"
    "xcodebuild -version"
    "brew install"
    "brew list"
    "mkdir"
    "touch"
    "echo"
    "yamllint"
)

# Function to build allowlist
build_allowlist() {
    local commands=("$@")
    local allowlist=""
    for cmd in "${commands[@]}"; do
        allowlist="$allowlist '$cmd'"
    done
    echo "$allowlist"
}

case $AGENT in
  architect)
    ALLOWLIST=$(build_allowlist "${ARCHITECT_SAFE[@]}")
    eval claude $ALLOWLIST \
          --system-prompt-file docs/agent-prompts/architect.md \
          \"$TASK\"
    ;;
  scrum|scrum-master)
    ALLOWLIST=$(build_allowlist "${SCRUM_SAFE[@]}")
    eval claude $ALLOWLIST \
          --system-prompt-file docs/agent-prompts/scrum-master.md \
          \"$TASK\"
    ;;
  engineer)
    ALLOWLIST=$(build_allowlist "${ENGINEER_SAFE[@]}")
    eval claude $ALLOWLIST \
          --system-prompt-file docs/agent-prompts/engineer.md \
          \"$TASK\"
    ;;
  qa)
    ALLOWLIST=$(build_allowlist "${QA_SAFE[@]}")
    eval claude $ALLOWLIST \
          --system-prompt-file docs/agent-prompts/qa.md \
          \"$TASK\"
    ;;
  devops)
    ALLOWLIST=$(build_allowlist "${DEVOPS_SAFE[@]}")
    eval claude $ALLOWLIST \
          --system-prompt-file docs/agent-prompts/devops.md \
          \"$TASK\"
    ;;
  *)
    echo "Unknown agent: $AGENT"
    echo "Available agents: architect, scrum, engineer, qa, devops"
    exit 1
    ;;
esac
