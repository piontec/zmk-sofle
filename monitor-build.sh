#!/bin/bash
# Monitor GitHub Actions build for the current branch

BRANCH=$(git branch --show-current)
POLL_INTERVAL=${1:-10}  # Default 10 seconds, can be overridden as first argument
MAX_WAIT=${2:-300}      # Default 5 minutes max wait

echo "Monitoring builds for branch: $BRANCH"
echo "Polling every ${POLL_INTERVAL}s (max wait: ${MAX_WAIT}s)"
echo "======================================"

WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    # Get the latest workflow run
    LATEST_RUN=$(gh run list --branch "$BRANCH" --workflow "Build ZMK firmware" --limit 1 --json databaseId,status,conclusion,displayTitle,createdAt --jq '.[0]')
    
    if [ "$LATEST_RUN" = "null" ] || [ -z "$LATEST_RUN" ]; then
        echo "No build found for branch $BRANCH"
        exit 1
    fi
    
    RUN_ID=$(echo "$LATEST_RUN" | jq -r '.databaseId')
    STATUS=$(echo "$LATEST_RUN" | jq -r '.status')
    CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.conclusion // "N/A"')
    TITLE=$(echo "$LATEST_RUN" | jq -r '.displayTitle')
    CREATED=$(echo "$LATEST_RUN" | jq -r '.createdAt')
    
    echo ""
    echo "[$(date +%H:%M:%S)] Latest Build:"
    echo "  Title: $TITLE"
    echo "  Status: $STATUS"
    echo "  Conclusion: $CONCLUSION"
    echo "  Run ID: $RUN_ID"
    
    if [ "$STATUS" = "completed" ]; then
        echo ""
        if [ "$CONCLUSION" = "success" ]; then
            echo "✅ Build SUCCESSFUL!"
            echo ""
            echo "View details: https://github.com/piontec/zmk-sofle/actions/runs/$RUN_ID"
            exit 0
        else
            echo "❌ Build FAILED"
            echo ""
            echo "Error details:"
            echo "----------------------------------------"
            gh run view "$RUN_ID" --log | grep -A 10 -E "devicetree error|CMake Error|Error:|FATAL ERROR" | head -30
            echo "----------------------------------------"
            echo ""
            echo "Full logs: https://github.com/piontec/zmk-sofle/actions/runs/$RUN_ID"
            exit 1
        fi
    else
        echo "  ⏳ Still $STATUS... (waited ${WAITED}s)"
        sleep $POLL_INTERVAL
        WAITED=$((WAITED + POLL_INTERVAL))
    fi
done

echo ""
echo "⏰ Max wait time reached. Build still in progress."
echo "View progress: https://github.com/piontec/zmk-sofle/actions/runs/$RUN_ID"
exit 2

