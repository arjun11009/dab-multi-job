#!/bin/bash

set -e

echo "🔍 Detecting changes..."

# Always fetch latest main
git fetch origin main

# Get changed files
CHANGED_FILES=$(git diff --name-only origin/main...HEAD)

echo "📂 Changed files:"
echo "$CHANGED_FILES"

# Resolve mapping file relative to script location (WORKS FROM ANYWHERE)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAPPING_FILE="$SCRIPT_DIR/../job_mapping.json"

echo "📄 Using mapping file: $MAPPING_FILE"

# Validate JSON (fail early if invalid)
jq . "$MAPPING_FILE" > /dev/null

JOBS_TO_RUN=()

# Loop through jobs
while IFS= read -r job; do
  echo "Checking job: $job"

  # Safe jq (prevents null crash)
  files=$(jq -r --arg job "$job" '.[$job] // [] | .[]' "$MAPPING_FILE")

  for changed in $CHANGED_FILES; do
    for f in $files; do
      if [[ "$changed" == "$f" ]]; then
        echo "Match found: $changed → $job"
        JOBS_TO_RUN+=("$job")
      fi
    done
  done

done < <(jq -r 'keys[]' "$MAPPING_FILE")

# Remove duplicates
JOBS_TO_RUN=($(printf "%s\n" "${JOBS_TO_RUN[@]}" | sort -u))

# If nothing changed
if [ ${#JOBS_TO_RUN[@]} -eq 0 ]; then
  echo "✅ No impacted jobs"
  exit 0
fi

echo "🚀 Jobs to run:"
printf '%s\n' "${JOBS_TO_RUN[@]}"

echo "📦 Deploying bundle..."
databricks bundle deploy

echo "🏃 Running jobs..."
for job in "${JOBS_TO_RUN[@]}"; do
  echo "▶ Running $job"
  databricks bundle run "$job"
done

echo "✅ Done"