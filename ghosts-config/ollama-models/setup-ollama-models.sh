#!/bin/bash
# Setup script for GHOSTS NPC Framework Ollama models
# Creates specialized model aliases from qwen3.5:9b with Korean-language system prompts

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo " GHOSTS NPC Ollama Model Setup"
echo "=========================================="
echo ""

# Check if ollama is available
if ! command -v ollama &> /dev/null; then
    echo "ERROR: ollama command not found. Please install Ollama first."
    exit 1
fi

# Check if base model is available
echo "Checking base model qwen3.5:9b..."
if ! ollama list | grep -q "qwen3.5:9b"; then
    echo "Base model qwen3.5:9b not found. Pulling..."
    ollama pull qwen3.5:9b
fi
echo "Base model ready."
echo ""

MODELS=(
    "social-valdoria-citizen"
    "social-valdoria-military"
    "social-valdoria-official"
    "social-krasnovia-official"
    "social-krasnovia-disguised"
    "social-bot"
    "social-gorgon"
    "social-media-reporter"
    "social-arventa"
    "social-tarvek"
)

TOTAL=${#MODELS[@]}
CURRENT=0
FAILED=0

for MODEL in "${MODELS[@]}"; do
    CURRENT=$((CURRENT + 1))
    MODELFILE="$SCRIPT_DIR/${MODEL}.modelfile"

    if [ ! -f "$MODELFILE" ]; then
        echo "[$CURRENT/$TOTAL] SKIP: $MODELFILE not found"
        FAILED=$((FAILED + 1))
        continue
    fi

    echo "[$CURRENT/$TOTAL] Creating model: $MODEL"
    if ollama create "$MODEL" -f "$MODELFILE"; then
        echo "         -> OK"
    else
        echo "         -> FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=========================================="
echo " Setup Complete"
echo " Created: $((TOTAL - FAILED))/$TOTAL models"
if [ $FAILED -gt 0 ]; then
    echo " Failed:  $FAILED"
fi
echo "=========================================="
echo ""
echo "Models are now available via 'ollama list'"
echo "Test with: ollama run social-valdoria-citizen"
