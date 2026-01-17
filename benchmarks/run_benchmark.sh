#!/bin/bash
# Full benchmark runner - tests multiple chunk sizes
#
# Usage: ./run_benchmark.sh [model]
# Example: ./run_benchmark.sh "000/glm-4.7-v4-fast"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LMSTUDIO_DIR="$HOME/.lmstudio/extensions/backends/vendor/_amphibian"
MODEL="${1:-glm-4.7-v4-fast}"
CHUNK_SIZES=(512 1024 2048 4096 8192)

echo "========================================"
echo "LM Studio MLX Prefill Benchmark"
echo "========================================"
echo ""
echo "Model: $MODEL"
echo "Chunk sizes: ${CHUNK_SIZES[*]}"
echo ""

patch_chunk_size() {
    local size=$1
    for f in "$LMSTUDIO_DIR"/*/lib/python3.11/site-packages/mlx_engine/cache_wrapper.py; do
        [ -f "$f" ] && sed -i '' "s/PROMPT_PROCESSING_CHUNK_SIZE = [0-9]*/PROMPT_PROCESSING_CHUNK_SIZE = $size/g" "$f"
    done
    for f in "$LMSTUDIO_DIR"/*/lib/python3.11/site-packages/mlx_lm/generate.py; do
        [ -f "$f" ] && sed -i '' "s/prefill_step_size: int = [0-9]*/prefill_step_size: int = $size/g" "$f"
    done
    find "$LMSTUDIO_DIR" -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
}

echo "Results:"
echo "--------"
printf "%-8s %-10s %-10s\n" "Chunk" "Time" "Speed"

for chunk in "${CHUNK_SIZES[@]}"; do
    # Quit LM Studio
    osascript -e 'quit app "LM Studio"' 2>/dev/null || true
    sleep 5
    
    # Patch
    patch_chunk_size "$chunk"
    
    # Start LM Studio
    open -a "LM Studio"
    sleep 15
    
    # Load model
    ~/.lmstudio/bin/lms load "$MODEL" --yes 2>/dev/null || true
    sleep 3
    
    # Run benchmark
    RANDOM_ID=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c 16)
    cat "$SCRIPT_DIR/benchmark_40k.txt" | jq -Rs --arg id "$RANDOM_ID" '{
      "model": "'"$MODEL"'",
      "messages": [{"role": "user", "content": (. + "\n[" + $id + "] Reply OK.")}],
      "max_tokens": 5, "stream": false
    }' > /tmp/bench_req.json
    
    START=$(date +%s)
    RESULT=$(curl -s --max-time 1800 http://localhost:1234/v1/chat/completions \
      -H "Content-Type: application/json" -d @/tmp/bench_req.json)
    END=$(date +%s)
    ELAPSED=$((END - START))
    
    TOKENS=$(echo "$RESULT" | jq -r '.usage.prompt_tokens // 0')
    if [ "$TOKENS" -gt 0 ]; then
        SPEED=$((TOKENS / ELAPSED))
        printf "%-8s %-10s %-10s\n" "$chunk" "${ELAPSED}s" "${SPEED} tok/s"
    else
        printf "%-8s %-10s %-10s\n" "$chunk" "timeout" "-"
    fi
done

# Reset to 4096
osascript -e 'quit app "LM Studio"' 2>/dev/null || true
sleep 3
patch_chunk_size 4096
echo ""
echo "Reset to 4096. Restart LM Studio to apply."
