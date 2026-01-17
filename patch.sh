#!/bin/bash
# LM Studio MLX Prefill Patch
# Increases chunk size for faster prompt processing

LMSTUDIO_DIR="$HOME/.lmstudio/extensions/backends/vendor/_amphibian"
DEFAULT_SIZE=4096

show_help() {
    echo "LM Studio MLX Prefill Patch"
    echo ""
    echo "Usage: $0 [chunk_size|--check|--help]"
    echo ""
    echo "  chunk_size  Set chunk size (default: 4096, stock: 512)"
    echo "  --check     Show current chunk size settings"
    echo "  --help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0          # Apply patch with default 4096"
    echo "  $0 8192     # Apply patch with 8192"
    echo "  $0 512      # Revert to stock settings"
    echo "  $0 --check  # Check current settings"
}

check_current() {
    echo "Current settings:"
    echo ""
    echo "cache_wrapper.py (PROMPT_PROCESSING_CHUNK_SIZE):"
    grep -rh "PROMPT_PROCESSING_CHUNK_SIZE = " "$LMSTUDIO_DIR"/*/lib/python3.11/site-packages/mlx_engine/cache_wrapper.py 2>/dev/null | sort | uniq -c | sed 's/^/  /'
    echo ""
    echo "generate.py (prefill_step_size):"
    grep -rh "prefill_step_size: int = " "$LMSTUDIO_DIR"/*/lib/python3.11/site-packages/mlx_lm/generate.py 2>/dev/null | sort | uniq -c | sed 's/^/  /'
}

apply_patch() {
    local size=$1
    
    echo "Patching LM Studio MLX backends to chunk size $size..."
    echo ""
    
    # Check if directory exists
    if [ ! -d "$LMSTUDIO_DIR" ]; then
        echo "Error: LM Studio backends not found at $LMSTUDIO_DIR"
        exit 1
    fi
    
    # Patch cache_wrapper.py
    local cache_count=0
    for f in "$LMSTUDIO_DIR"/*/lib/python3.11/site-packages/mlx_engine/cache_wrapper.py; do
        if [ -f "$f" ]; then
            sed -i '' "s/PROMPT_PROCESSING_CHUNK_SIZE = [0-9]*/PROMPT_PROCESSING_CHUNK_SIZE = $size/g" "$f"
            ((cache_count++))
        fi
    done
    
    # Patch generate.py
    local gen_count=0
    for f in "$LMSTUDIO_DIR"/*/lib/python3.11/site-packages/mlx_lm/generate.py; do
        if [ -f "$f" ]; then
            sed -i '' "s/prefill_step_size: int = [0-9]*/prefill_step_size: int = $size/g" "$f"
            ((gen_count++))
        fi
    done
    
    # Clear Python cache
    find "$LMSTUDIO_DIR" -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    
    echo "✓ Patched $cache_count cache_wrapper.py files"
    echo "✓ Patched $gen_count generate.py files"
    echo ""
    
    # Verify
    echo "Verification:"
    check_current
    
    echo ""
    echo "⚠️  Restart LM Studio for changes to take effect!"
}

# Parse arguments
case "$1" in
    --help|-h)
        show_help
        exit 0
        ;;
    --check|-c)
        check_current
        exit 0
        ;;
    "")
        apply_patch $DEFAULT_SIZE
        ;;
    *)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            apply_patch "$1"
        else
            echo "Error: Invalid argument '$1'"
            echo ""
            show_help
            exit 1
        fi
        ;;
esac
