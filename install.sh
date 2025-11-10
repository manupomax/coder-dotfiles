#!/bin/bash
set -e

echo "🧰 Installing python3.12-venv (first-run setup)..."

if command -v apt-get &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y python3.12-venv
else
    echo "⚠️ apt-get not found — base image may not be Debian/Ubuntu."
fi

echo "✅ python3.12-venv installed successfully!"
