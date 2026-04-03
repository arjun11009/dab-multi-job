#!/bin/bash

set -e

echo "=============================="
echo " Detecting changes..."
echo "=============================="

# ==============================
# Validate dependencies
# ==============================
if ! command -v git &> /dev/null; then
  echo "ERROR: git is not installed"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed (required for JSON parsing)"
  exit 1
fi

# ==============================
# Change Detection Strategy
# ==============================
echo ""
echo "Determining diff strategy..."

if [ -n "$CI" ]; then
  echo "Running in CI environment"

  if [ -n "$CI_COMMIT_BEFORE_SHA" ] && [ -n "$CI_COMMIT_SHA" ]; then
    echo "Using GitLab CI diff"
    CHANGED_FILES=$(git diff --name-only "$CI_COMMIT_BEFORE_SHA" "$CI_COMMIT_SHA" | tr -d '\r')

  elif [ -n "$GITHUB_SHA" ]; then
    echo "Using GitHub Actions diff"
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD | tr -d '\r')

  else
    echo "CI detected but fallback to HEAD diff"
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD | tr -d '\r')
  fi

else
  echo "Running locally"

  if git rev-parse HEAD^2 >/dev/null 2>&1; then
    echo "Merge commit detected → using HEAD~1"
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD | tr -d '\r')
  else
    echo "Normal commit → using HEAD~1"
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD | tr -d '\r')
  fi
fi

# Remove empty lines
CHANGED_FILES=$(echo "$CHANGED_FILES" | sed '/^\s*$/d')

echo ""
echo "Changed files:"
echo "------------------------------"
echo "$CHANGED_FILES"

# Exit if no changes
if [ -z "$CHANGED_FILES" ]; then
  echo "No changes detected"
  exit 0
fi

# ==============================
# Resolve directories
# ==============================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCE_DIR="$SCRIPT_DIR/../resources"

if [ ! -d "$RESOURCE_DIR" ]; then
  echo "ERROR: resources directory not found at $RESOURCE_DIR"
  exit 1
fi

JOBS_TO_RUN=()

echo ""
echo "=============================="
echo " Scanning meta files..."
echo "=============================="

# ==============================
# Process meta files
# ==============================
for meta_file in "$RESOURCE_DIR"/*.meta.json; do

  echo ""
  echo "Processing meta file: $meta_file"

  job_name=$(jq -r '.job_name' "$meta_file")

  if [ -z "$job_name" ] || [ "$job_name" == "null" ]; then
    echo "WARNING: Invalid job_name in $meta_file"
    continue
  fi

  echo "Checking job: $job_name"

  paths=$(jq -r '.paths[]' "$meta_file")

  job_matched=false

  # Loop changed files
  while IFS= read -r changed; do
    changed_clean=$(echo "$changed" | sed 's|^\./||' | xargs)

    # Loop paths
    while IFS= read -r path; do
      path_clean=$(echo "$path" | sed 's|^\./||' | xargs)

      if [[ -z "$path_clean" ]]; then
        continue
      fi

      # ---- MATCH LOGIC ----

      # Directory match
      if [[ "$path_clean" == */ ]]; then
        if [[ "$changed_clean" == "$path_clean"* ]]; then
          echo " Match found: $changed_clean → $job_name"
          JOBS_TO_RUN+=("$job_name")
          job_matched=true
          break
        fi
      else
        # File OR prefix match
        if [[ "$changed_clean" == "$path_clean" ]] || [[ "$changed_clean" == "$path_clean"* ]]; then
          echo " Match found: $changed_clean → $job_name"
          JOBS_TO_RUN+=("$job_name")
          job_matched=true
          break
        fi
      fi

    done <<< "$paths"

    if [ "$job_matched" = true ]; then
      break
    fi

  done <<< "$CHANGED_FILES"

done

# ==============================
# Remove duplicates
# ==============================
JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))

echo ""
echo "=============================="
echo " Job Selection Summary"
echo "=============================="

# ==============================
# Fallback strategy
# ==============================
if [ ${#JOBS_TO_RUN[@]} -eq 0 ]; then
  echo "No impacted jobs detected"
  echo "Fallback: Running ALL jobs"

  JOBS_TO_RUN=()

  for meta_file in "$RESOURCE_DIR"/*.meta.json; do
    job_name=$(jq -r '.job_name' "$meta_file")
    JOBS_TO_RUN+=("$job_name")
  done

  JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))
fi

echo ""
echo "Jobs to run:"
echo "------------------------------"
printf '%s\n' "${JOBS_TO_RUN[@]}"

# ==============================
# Deploy bundle
# ==============================
echo ""
echo "=============================="
echo " Deploying bundle..."
echo "=============================="

databricks bundle deploy

# ==============================
# Run jobs
# ==============================
echo ""
echo "=============================="
echo " Running jobs..."
echo "=============================="

for job in "${JOBS_TO_RUN[@]}"; do
  echo ""
  echo "Running job: $job"
  databricks bundle run "$job" || echo "WARNING: Job $job failed"
done

echo ""
echo "=============================="
echo " Done"
echo "=============================="