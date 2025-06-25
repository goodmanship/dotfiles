#!/bin/bash

echo "🏠 Simple room cleaning - keeping only main (and current branch)"

# Make sure we're on main
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo "📍 Currently on: $CURRENT_BRANCH"
    echo "🔄 Switching to main..."
    git checkout main
fi

# Show branches sorted by commit date (newest first)
echo ""
echo "🗑️  About to delete these local branches:"
echo ""
printf "  %-30s %-12s %s\n" "󰘬 Branch" "📅 Date" "💬 Last Commit"
printf "  %-30s %-12s %s\n" "──────────────────────────────" "──────────" "─────────────────────────────────"
# Show branches sorted by commit date (newest first)
git for-each-ref --format='%(refname:short)|%(committerdate:short)|%(contents:subject)' refs/heads/ --sort=-committerdate | grep -v "^main|" | while IFS='|' read -r branch date message; do
    # Truncate branch name if longer than 27 chars (leave room for padding)
    if [ ${#branch} -gt 27 ]; then
        branch="${branch:0:24}..."
    fi
    printf "  %-30s %-12s %s\n" "$branch" "$date" "$message"
done

echo ""
read -p "🚨 Continue? This will delete ALL local branches except main. (y/N): " confirm

if [[ $confirm != [yY] ]]; then
    echo "❌ Cancelled. Your branches are safe."
    exit 0
fi

echo ""
echo "💥 Deleting all branches except main..."
git branch | grep -v -E "(main|\*)" | xargs -n 1 git branch -D

echo ""
echo "✅ Room cleaned!"
echo "📊 Remaining local branches:"
git branch

echo ""
echo "🌐 Remote branches untouched - still the wild west out there!"
