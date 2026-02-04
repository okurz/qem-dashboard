#!/bin/bash
set -e

# Configuration
BOT_DIR=${BOT_DIR:-../qem-bot}
QEM_DASHBOARD_URL=${QEM_DASHBOARD_URL:-http://localhost:3000}

echo "Running qem-bot integration test against $QEM_DASHBOARD_URL"

if [ ! -d "$BOT_DIR" ]; then
    echo "Error: BOT_DIR ($BOT_DIR) not found"
    exit 1
fi

cd "$BOT_DIR"

# Run gitea-sync with fake data
# This uses internal 'responses' to generate PR data and attempts to push to Dashboard
echo "Executing: qem-bot.py gitea-sync --fake-data"
export QEM_DASHBOARD_URL
python3 qem-bot.py gitea-sync \
    --fake-data \
    --configs tests/data/config \
    --gitea-token "fake-token" \
    --token "fake-dashboard-token" \
    --retry 0

echo "Verifying dashboard connectivity..."
curl -sf "$QEM_DASHBOARD_URL/api/v1/incidents" > /dev/null

echo "Integration test passed!"
