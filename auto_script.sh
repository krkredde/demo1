#!/bin/bash

# This script automates the process of creating a PR, checking CI status, and merging

# Configuration variables
BRANCH_NAME="auto_merge"
BASE_BRANCH="main"  # Default to "main" if no base branch is provided
PR_TITLE=${3:-"Automated PR"}
PR_BODY=${4:-"This is an automated pull request created by a script."}
REPO_NAME=$(basename -s .git `git config --get remote.origin.url`)

# Ensure you are in a git repository
if [ ! -d ".git" ]; then
  echo "Error: Not a git repository!"
  exit 1
fi

# Ensure the GitHub CLI is installed
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is not installed."
  exit 1
fi

# Step 1: Create a new branch
echo "Creating and switching to branch '$BRANCH_NAME'..."
git checkout -b "$BRANCH_NAME"

# Step 2: Push the branch to GitHub
echo "Pushing branch '$BRANCH_NAME' to remote repository..."
git push origin "$BRANCH_NAME"

# Step 3: Create the pull request
echo "Creating pull request from '$BRANCH_NAME' to '$BASE_BRANCH'..."
gh pr create --base "$BASE_BRANCH" --head "$BRANCH_NAME" --title "$PR_TITLE" --body "$PR_BODY" --assignee @me --label "automated" --draft

# Step 4: Wait for CI checks to pass (optional: integrate with GitHub Actions or other CI tools)
# This step assumes GitHub Actions or another CI tool is configured to run checks on PRs
# We will wait until the PR checks pass
echo "Waiting for CI checks to pass..."

PR_URL=$(gh pr view --json url -q ".url")
echo "Checking CI status for PR: $PR_URL"

while true; do
  # Fetch the status of the checks for this PR
  STATUS=$(gh pr checks "$BRANCH_NAME" --json status -q ".status")

  # If all checks pass, the status should be 'success'
  if [[ "$STATUS" == "success" ]]; then
    echo "All CI checks passed. Proceeding with the merge."
    break
  fi

  echo "CI checks are not passing yet. Waiting..."
  sleep 30  # Check every 30 seconds
done

# Step 5: Merge the PR
echo "Merging the pull request..."
gh pr merge "$BRANCH_NAME" --merge --delete-branch

echo "Pull request merged and branch deleted."
