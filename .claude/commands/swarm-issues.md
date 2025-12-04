---
description: Build swarm work manifest from tagged GitHub issues and execute
argument-hint: [--label swarm-ready] [--execute] [--dry-run]
---

# /swarm-issues - Execute Swarm from GitHub Issues

<objective>
Fetch GitHub issues with a specific label, generate a work manifest, and optionally
execute the swarm. Enables using GitHub Issues as your task backlog with automatic
distributed execution.
</objective>

<user-provides>
Label to filter issues (defaults to "swarm-ready")
</user-provides>

<command-delivers>
Generated work manifest, optionally executed across agents with PRs linked back to issues
</command-delivers>

## Usage

```bash
# Preview what would be processed (dry run)
/swarm-issues --dry-run

# Generate manifest and execute
/swarm-issues --execute

# Use custom label
/swarm-issues --label "sprint-47" --execute

# Just generate the manifest file (don't execute)
/swarm-issues --label "ready-for-ai" --output sprint-47.yaml
```

## How It Works

<issue-discovery>
Use GitHub CLI to fetch open issues with the specified label:

```bash
gh issue list --label "swarm-ready" --state open --json number,title,body,labels
```

For each issue, extract:
- Issue number → becomes task ID
- Title → used in branch name
- Body → becomes the task prompt
- Labels → can indicate priority or dependencies
</issue-discovery>

<branch-naming>
Generate branch names from issue titles:

```
Issue: "Add OAuth2 token refresh" (#142)
Branch: feature/142-oauth2-token-refresh

Issue: "[BUG] Session timeout not working" (#156)
Branch: fix/156-session-timeout
```

Sanitize titles: lowercase, replace spaces with hyphens, remove special characters,
prefix with issue number for uniqueness.
</branch-naming>

<dependency-detection>
Look for dependency markers in issue body:

```markdown
## Dependencies
- Depends on #142
- Blocked by #145
```

Or use GitHub's "blocked by" syntax if available. These become `depends_on` in manifest.
</dependency-detection>

<priority-detection>
Map labels to priorities:

- `priority:high` or `urgent` → high
- `priority:low` or `nice-to-have` → low
- Default → medium

Also respect label order if multiple priority labels exist.
</priority-detection>

<manifest-generation>
Generate YAML manifest from discovered issues:

```yaml
# Auto-generated from GitHub issues
# Label: swarm-ready
# Generated: 2024-01-15T10:30:00Z

name: "Swarm from GitHub Issues (swarm-ready)"
base_branch: main

tasks:
  - id: "142"
    prompt: |
      Issue #142: Add OAuth2 token refresh
      
      [Full issue body here]
      
      Original issue: https://github.com/org/repo/issues/142
    branch: feature/142-oauth2-token-refresh
    priority: high
    
  - id: "156"
    prompt: |
      Issue #156: Session timeout not working
      
      [Full issue body here]
      
      Original issue: https://github.com/org/repo/issues/156
    branch: fix/156-session-timeout
    depends_on: ["142"]
```
</manifest-generation>

<execution>
If `--execute` flag provided, run `/swarm` with generated manifest.

After each task completes:
1. Add comment to issue with PR link
2. Optionally close issue (if `--auto-close` flag)
3. Remove swarm label, add "in-progress" or "pr-ready" label
</execution>

<issue-update>
After PR is created, update the original issue:

```markdown
🤖 **Swarm Bot**: PR created!

Pull Request: #789
Branch: `feature/142-oauth2-token-refresh`
Status: Ready for review

---
*Processed by /swarm-issues at 2024-01-15T10:45:00Z*
```

Link PR to issue using GitHub's "Closes #142" in PR description.
</issue-update>

## Issue Format Best Practices

For best results, structure your issues like this:

```markdown
## Description
Clear description of what needs to be done.

## Acceptance Criteria
- [ ] Feature works as expected
- [ ] Tests are included
- [ ] Documentation updated

## Dependencies
- Depends on #142 (optional)

## Technical Notes
Any implementation hints or constraints (optional)
```

The entire issue body becomes the task prompt, so write it as instructions for an
autonomous developer.

## Labels for Control

| Label | Effect |
|-------|--------|
| `swarm-ready` | Issue will be picked up (default) |
| `priority:high` | Task runs with high priority |
| `priority:low` | Task runs with low priority |
| `blocked` | Issue skipped until label removed |
| `needs-clarification` | Issue skipped, needs human input |

## Example Workflow

1. **Create issues** as you normally would
2. **Tag with `swarm-ready`** when issue is clear enough for AI
3. **Run** `/swarm-issues --execute`
4. **Review PRs** that get created
5. **Merge** when satisfied

```
GitHub Issues                    Swarm                         PRs
┌─────────────┐                                          ┌─────────────┐
│ #142 OAuth  │──┐                                   ┌──→│ PR #789     │
│ [swarm-ready]│  │    ┌─────────────────┐          │   └─────────────┘
└─────────────┘  ├───→│ /swarm-issues   │──────────┤
┌─────────────┐  │    │ --execute       │          │   ┌─────────────┐
│ #156 Timeout│──┘    └─────────────────┘          └──→│ PR #790     │
│ [swarm-ready]│                                        └─────────────┘
└─────────────┘
```

## Flags

| Flag | Description |
|------|-------------|
| `--label <name>` | Label to filter issues (default: swarm-ready) |
| `--execute` | Run swarm after generating manifest |
| `--dry-run` | Show what would be processed, don't execute |
| `--output <file>` | Save manifest to file instead of executing |
| `--auto-close` | Close issues when PR is merged |
| `--local` | Pass to swarm: run sequentially on local machine |
| `--limit <n>` | Maximum issues to process |
| `--repo <owner/repo>` | Target repo (default: current) |

## Requirements

- GitHub CLI (`gh`) installed and authenticated
- Write access to repository (for updating issues)
- Issues must be open and have the target label

## State Tracking

Creates `.swarm/issues-state.json` to track:
- Which issues have been processed
- Which PRs were created for which issues
- Timestamp of last run

This prevents re-processing issues that are already in progress.

## See Also

- @.claude/commands/swarm.md - Core swarm execution
- @context/swarm-work-manifest.md - Manifest format
- @.claude/skills/swarm-orchestration/SKILL.md - Distributed patterns
