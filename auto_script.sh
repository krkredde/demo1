#!/bin/bash

# This script automates the process of creating a PR, checking CI status, and merging to main.

# Configuration variables
BRANCH_NAME="auto_merge"   # The name of the branch you want to create the PR from
BASE_BRANCH="main"         # The target branch for the PR (default is 'main')
PR_TITLE="Automated PR to main"
PR_BODY="This PR is automatically created and merged from the auto_merge branch."
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

# Step 1: Ensure we are on the correct base branch (main)
echo "Switching to base branch '$BASE_BRANCH'..."
git checkout "$BASE_BRANCH"
git pull origin "$BASE_BRANCH"  # Pull the latest changes from the base branch

# Step 2: Create a new branch 'auto_merge' (if not already existing)
echo "Checking out and preparing '$BRANCH_NAME'..."
git checkout -b "$BRANCH_NAME"

# Step 3: Push the branch to GitHub
echo "Pushing branch '$BRANCH_NAME' to remote repository..."
git push origin "$BRANCH_NAME"

# Step 4: Create the Pull Request
echo "Creating pull request from '$BRANCH_NAME' to '$BASE_BRANCH'..."
PR_URL=$(gh pr create --base "$BASE_BRANCH" --head "$BRANCH_NAME" --title "$PR_TITLE" --body "$PR_BODY" --assignee @me --label "automated" --draft --json url -q ".url")

# Step 5: Monitor CI status (using GitHub Actions or other CI/CD tools)
echo "Waiting for CI checks to pass on PR: $PR_URL"

# Function to check the CI status of the PR
check_ci_status() {
  # Fetch the PR's checks
  CHECKS=$(gh pr checks "$BRANCH_NAME" --json checkRuns -q ".checkRuns[] | {name: .name, state: .state, conclusion: .conclusion}")
  
  # Check if all checks have completed successfully
  # If any check's state is 'queued' or 'in_progress', return 1 (checks not finished yet)
  # If any check's conclusion is not 'success', return 1 (check failed)
  if [[ "$(echo "$CHECKS" | jq -r 'map(select(.state != "completed" or .conclusion != "success")) | length')" -eq 0 ]]; then
    return 0  # All checks passed and completed
  else
    return 1  # One or more checks are still pending or failed
  fi
}

# Polling the CI status until all checks pass
while true; do
  check_ci_status
  if [ $? -eq 0 ]; then
    echo "All CI checks passed. Proceeding with the merge."
    break
  else
    echo "CI checks are still in progress or have failed. Waiting..."
    sleep 30  # Wait for 30 seconds before checking again
  fi
done

# Step 6: Merge the PR
echo "Merging the pull request into '$BASE_BRANCH'..."
gh pr merge "$BRANCH_NAME" --merge --delete-branch

echo "Pull request has been merged and the branch has been deleted."
