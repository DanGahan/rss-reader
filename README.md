
## AI Agent Team

### Agents

1. **Architect** - Technical design and architecture
2. **Scrum Master** - Story breakdown and sprint planning
3. **Engineer** - Code implementation
4. **QA** - Quality assurance and testing
5. **DevOps** - CI/CD pipelines and build automation

### Agent Usage
```bash
# DevOps examples
./run-agent.sh devops "Create GitHub Actions workflow for PR validation"
./run-agent.sh devops "Optimize build times with caching"
./run-agent.sh devops "Setup automated releases"
```

### Agent Permissions

Each agent has carefully scoped command permissions:

- **Architect:** Read-only + documentation creation
- **Scrum Master:** GitHub issue/label management
- **Engineer:** Full dev workflow (branch, commit, PR)
- **QA:** Testing + PR review
- **DevOps:** Pipeline management + build automation
