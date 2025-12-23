#!/bin/bash

# Script to monitor GitHub Actions build results for zmk-sofle
# Usage: 
#   ./check_build.sh                    - Check build status once
#   ./check_build.sh --watch            - Continuously monitor build status
#   ./check_build.sh --auto             - Run in background, auto-start on login
#   ./check_build.sh --commit           - Commit and push changes, then monitor
#   ./check_build.sh --limit N          - Show N workflow runs

set -e

WATCH=false
LIMIT=5
AUTO_COMMIT=false
AUTO_MODE=false
COMMIT_MESSAGE=""
REPO_OWNER=""
REPO_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch|-w)
            WATCH=true
            shift
            ;;
        --auto|-a)
            AUTO_MODE=true
            WATCH=true
            shift
            ;;
        --limit|-l)
            LIMIT="$2"
            shift 2
            ;;
        --commit|-c)
            AUTO_COMMIT=true
            shift
            ;;
        --message|-m)
            COMMIT_MESSAGE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--watch|--auto] [--limit N] [--commit] [--message \"commit message\"]"
            exit 1
            ;;
    esac
done

# Get repository info from git remote
get_repo_info() {
    local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -z "$remote_url" ]]; then
        echo "Error: Not in a git repository or no origin remote found" >&2
        exit 1
    fi
    
    # Extract owner/repo from various URL formats
    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]%.git}"
    else
        echo "Error: Could not parse repository URL: $remote_url" >&2
        exit 1
    fi
}

# Check if gh CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI (gh) is not installed" >&2
        echo "Install it from: https://cli.github.com/" >&2
        exit 1
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        echo "Error: Not authenticated with GitHub CLI" >&2
        echo "Run: gh auth login" >&2
        exit 1
    fi
}

# Get latest workflow runs
get_workflow_runs() {
    gh run list --repo "$REPO_OWNER/$REPO_NAME" --limit "$LIMIT" --json databaseId,status,conclusion,name,workflowName,createdAt,headBranch,event
}

# Display run information
display_run_info() {
    local run_id=$1
    local status=$2
    local conclusion=$3
    local name=$4
    local workflow=$5
    local created=$6
    local branch=$7
    local event=$8
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Run ID: $run_id"
    echo "Workflow: $workflow"
    echo "Name: $name"
    echo "Branch: $branch"
    echo "Event: $event"
    echo "Created: $created"
    echo "Status: $status"
    if [[ -n "$conclusion" ]]; then
        echo "Conclusion: $conclusion"
    fi
    echo ""
}

# Check build status with color coding
check_build_status() {
    get_repo_info
    check_gh_cli
    
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local has_changes=$(git status --porcelain 2>/dev/null | wc -l)
    
    echo "Checking build status for: $REPO_OWNER/$REPO_NAME"
    echo "Current branch: $current_branch"
    if [[ "$has_changes" -gt 0 ]]; then
        echo "⚠️  Warning: You have uncommitted changes"
    fi
    echo ""
    
    # Get workflow runs
    local runs_json=$(get_workflow_runs)
    
    if [[ -z "$runs_json" ]] || [[ "$runs_json" == "[]" ]]; then
        echo "No workflow runs found."
        return 1
    fi
    
    # Parse and display runs
    local run_count=$(echo "$runs_json" | jq '. | length')
    echo "Found $run_count workflow run(s):"
    echo ""
    
    for ((i=0; i<run_count; i++)); do
        local run_id=$(echo "$runs_json" | jq -r ".[$i].databaseId")
        local status=$(echo "$runs_json" | jq -r ".[$i].status")
        local conclusion=$(echo "$runs_json" | jq -r ".[$i].conclusion // \"\"")
        local name=$(echo "$runs_json" | jq -r ".[$i].name")
        local workflow=$(echo "$runs_json" | jq -r ".[$i].workflowName")
        local created=$(echo "$runs_json" | jq -r ".[$i].createdAt")
        local branch=$(echo "$runs_json" | jq -r ".[$i].headBranch")
        local event=$(echo "$runs_json" | jq -r ".[$i].event")
        
        display_run_info "$run_id" "$status" "$conclusion" "$name" "$workflow" "$created" "$branch" "$event"
        
        # Get latest run details
        if [[ $i -eq 0 ]]; then
            echo "Latest run details:"
            echo "──────────────────────────────────────────────────────────────────────────"
            gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" || true
            echo ""
            
            # Show logs if in progress or failed
            if [[ "$status" == "in_progress" ]] || [[ "$status" == "queued" ]]; then
                echo "Build is currently running. Showing live logs:"
                echo "──────────────────────────────────────────────────────────────────────────"
                gh run watch "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --exit-status || true
            elif [[ "$conclusion" == "failure" ]] || [[ "$conclusion" == "cancelled" ]]; then
                echo "Build failed. Showing logs:"
                echo "──────────────────────────────────────────────────────────────────────────"
                gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --log-failed || true
            fi
        fi
    done
    
    # Summary
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local latest_status=$(echo "$runs_json" | jq -r ".[0].status")
    local latest_conclusion=$(echo "$runs_json" | jq -r ".[0].conclusion // \"\"")
    local latest_branch=$(echo "$runs_json" | jq -r ".[0].headBranch")
    
    # Check if latest build is for current branch
    if [[ "$current_branch" != "unknown" ]] && [[ "$latest_branch" != "$current_branch" ]]; then
        echo "⚠️  Note: Latest build shown is for branch '$latest_branch', not current branch '$current_branch'"
        echo ""
    fi
    
    if [[ "$latest_status" == "completed" ]] && [[ "$latest_conclusion" == "success" ]]; then
        echo "✓ Latest build: SUCCESS"
        if [[ "$has_changes" -gt 0 ]]; then
            echo ""
            echo "💡 Tip: You have uncommitted changes. Commit and push to trigger a new build:"
            echo "   git add ."
            echo "   git commit -m 'Add zmk-rgb-fx integration'"
            echo "   git push"
        fi
        return 0
    elif [[ "$latest_status" == "completed" ]] && [[ "$latest_conclusion" == "failure" ]]; then
        echo "✗ Latest build: FAILED"
        return 1
    elif [[ "$latest_status" == "in_progress" ]] || [[ "$latest_status" == "queued" ]]; then
        echo "⏳ Latest build: IN PROGRESS"
        return 2
    else
        echo "? Latest build: $latest_status ($latest_conclusion)"
        return 3
    fi
}

# Watch mode - continuously check build status
watch_build() {
    local interval=30  # Default 30 seconds
    local last_status=""
    local notification_sent=false
    
    echo "Watching build status (press Ctrl+C to stop)..."
    echo "Checking every ${interval} seconds"
    echo ""
    
    while true; do
        local current_time=$(date '+%Y-%m-%d %H:%M:%S')
        local runs_json=$(get_workflow_runs)
        
        if [[ -z "$runs_json" ]] || [[ "$runs_json" == "[]" ]]; then
            echo "[$current_time] No workflow runs found"
            sleep $interval
            continue
        fi
        
        local latest_status=$(echo "$runs_json" | jq -r ".[0].status")
        local latest_conclusion=$(echo "$runs_json" | jq -r ".[0].conclusion // \"\"")
        local latest_branch=$(echo "$runs_json" | jq -r ".[0].headBranch")
        local run_id=$(echo "$runs_json" | jq -r ".[0].databaseId")
        local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        
        # Only show output if status changed or if it's in progress
        if [[ "$latest_status" != "$last_status" ]] || [[ "$latest_status" == "in_progress" ]] || [[ "$latest_status" == "queued" ]]; then
            clear
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Build Monitor - Last checked: $current_time"
            echo "Current branch: $current_branch"
            echo "Latest build branch: $latest_branch"
            echo ""
            
            if [[ "$latest_status" == "completed" ]]; then
                if [[ "$latest_conclusion" == "success" ]]; then
                    echo "✓ Build SUCCESS"
                    if [[ "$notification_sent" == false ]]; then
                        notify-send "ZMK Build" "Build completed successfully!" 2>/dev/null || true
                        notification_sent=true
                    fi
                elif [[ "$latest_conclusion" == "failure" ]]; then
                    echo "✗ Build FAILED"
                    echo ""
                    echo "Run ID: $run_id"
                    echo "View logs: gh run view $run_id --log-failed"
                    if [[ "$notification_sent" == false ]]; then
                        notify-send "ZMK Build" "Build failed! Check logs." --urgency=critical 2>/dev/null || true
                        notification_sent=true
                    fi
                else
                    echo "? Build completed with conclusion: $latest_conclusion"
                fi
            elif [[ "$latest_status" == "in_progress" ]] || [[ "$latest_status" == "queued" ]]; then
                echo "⏳ Build $latest_status"
                echo ""
                echo "Run ID: $run_id"
                echo "View progress: gh run view $run_id --web"
                notification_sent=false
            else
                echo "? Build status: $latest_status"
            fi
            
            echo ""
            echo "Next check in ${interval} seconds... (Ctrl+C to stop)"
            last_status="$latest_status"
        else
            # Silent mode - just show a dot to indicate it's running
            echo -n "."
        fi
        
        sleep $interval
    done
}

# Auto-commit and push changes
auto_commit_and_push() {
    local current_branch=$(git branch --show-current 2>/dev/null || echo "")
    if [[ -z "$current_branch" ]]; then
        echo "Error: Not in a git repository" >&2
        return 1
    fi
    
    local has_changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ "$has_changes" -eq 0 ]]; then
        echo "No changes to commit."
        return 0
    fi
    
    echo "Committing and pushing changes..."
    echo ""
    
    # Generate commit message if not provided
    if [[ -z "$COMMIT_MESSAGE" ]]; then
        COMMIT_MESSAGE="Update ZMK configuration"
    fi
    
    # Add all changes
    git add -A
    
    # Commit
    git commit -m "$COMMIT_MESSAGE" || {
        echo "Error: Failed to commit changes" >&2
        return 1
    }
    
    # Push
    echo "Pushing to origin/$current_branch..."
    git push origin "$current_branch" || {
        echo "Error: Failed to push changes" >&2
        return 1
    }
    
    echo ""
    echo "✓ Successfully committed and pushed changes"
    echo "  Commit message: $COMMIT_MESSAGE"
    echo "  Branch: $current_branch"
    echo ""
    echo "Waiting a few seconds for GitHub Actions to start..."
    sleep 5
}

# Setup auto-start (runs in background)
setup_auto_start() {
    local script_path=$(realpath "$0")
    local systemd_user_dir="$HOME/.config/systemd/user"
    
    mkdir -p "$systemd_user_dir"
    
    cat > "$systemd_user_dir/zmk-build-monitor.service" <<EOF
[Unit]
Description=ZMK Build Monitor
After=network.target

[Service]
Type=simple
ExecStart=$script_path --watch
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable zmk-build-monitor.service
    systemctl --user start zmk-build-monitor.service
    
    echo "✓ Auto-monitoring enabled"
    echo "  Service installed at: $systemd_user_dir/zmk-build-monitor.service"
    echo ""
    echo "To check status: systemctl --user status zmk-build-monitor"
    echo "To stop: systemctl --user stop zmk-build-monitor"
    echo "To disable: systemctl --user disable zmk-build-monitor"
}

# Main execution
if [[ "$AUTO_COMMIT" == "true" ]]; then
    auto_commit_and_push
fi

if [[ "$AUTO_MODE" == "true" ]]; then
    setup_auto_start
elif [[ "$WATCH" == "true" ]]; then
    watch_build
else
    check_build_status
fi

