#!/bin/bash

set -e

echo "🔍 Detecting changes..."

git fetch origin main

CHANGED_FILES=$(git diff --name-only origin/main...HEAD | tr -d '\r')

echo "📂 Changed files:"
echo "$CHANGED_FILES"

RUN_BRONZE=false
RUN_SILVER=false

# Detect changes
while IFS= read -r file; do

  if [[ "$file" == src/bronze/* ]]; then
    RUN_BRONZE=true
  fi

  if [[ "$file" == src/silver/* ]]; then
    RUN_SILVER=true
  fi

  if [[ "$file" == src/common/* ]]; then
    RUN_BRONZE=true
    RUN_SILVER=true
  fi

done <<< "$CHANGED_FILES"

# If nothing changed
if ! $RUN_BRONZE && ! $RUN_SILVER; then
  echo "✅ No impacted jobs"
  exit 0
fi

echo "🚀 Jobs to run:"

$RUN_BRONZE && echo "bronze_job"
$RUN_SILVER && echo "silver_job"

echo "📦 Deploying bundle..."
databricks bundle deploy

echo "🏃 Running jobs..."

$RUN_BRONZE && databricks bundle run bronze_job
$RUN_SILVER && databricks bundle run silver_job

echo "✅ Done"