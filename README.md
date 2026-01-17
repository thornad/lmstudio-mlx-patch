# LM Studio MLX Prefill Patch

Speed up prompt processing (prefill) in LM Studio on Apple Silicon by increasing the chunk size from the default 512 to 4096.

## Results

**Test Setup:**
- Mac M3 Ultra (80-core GPU, 512GB RAM)
- ~41k token prompt
- LM Studio API

*Results may vary on different hardware configurations.*

| Chunk Size | V4 Speed | V5 Speed | V4 Advantage |
|------------|----------|----------|--------------|
| 512 (default) | 65 tok/s | - | baseline |
| 1024 | 102 tok/s | 85 tok/s | +20% |
| 2048 | 119 tok/s | 111 tok/s | +7% |
| 4096 | **129 tok/s** | 117 tok/s | +10% |
| 8192 | 128 tok/s | 117 tok/s | +9% |

### Key Findings

- **Optimal setting: 4096** - best balance of speed and consistency
- **4096 vs default 512: 2x faster** (129 vs 65 tok/s)
- **V4 beats V5** at all chunk sizes for prefill
- Diminishing returns above 4096
- 8192 has higher run-to-run variance

## Usage

```bash
# Apply patch (sets chunk size to 4096)
./patch.sh

# Or specify a custom chunk size
./patch.sh 8192

# Check current setting
./patch.sh --check

# Revert to stock
./patch.sh 512
```

**Important:** Restart LM Studio after patching for changes to take effect.

## Running Benchmarks

```bash
# Run full benchmark across all chunk sizes (takes ~1 hour)
cd benchmarks
./run_benchmark.sh "your-model-name"

# Or run a single test via API
python3 benchmark_api.py benchmark_40k.txt "model-name" 3

# Or use mlx_lm directly (requires LM Studio's Python)
~/.lmstudio/extensions/backends/vendor/_amphibian/app-mlx-generate-mac-arm64@*/bin/python3 \
  benchmark_prefill.py --model /path/to/model --runs 3
```

## What it patches

The script modifies two files in each MLX backend:

- `mlx_engine/cache_wrapper.py` - `PROMPT_PROCESSING_CHUNK_SIZE`
- `mlx_lm/generate.py` - `prefill_step_size`

Location:
```
~/.lmstudio/extensions/backends/vendor/_amphibian/*/lib/python3.11/site-packages/
```

## Why it works

The default chunk size of 512 processes prompts in small batches, requiring many iterations. Larger chunks (4096) reduce overhead and better utilize the GPU's parallel processing capabilities. However, very large chunks (8192+) can cause memory pressure and diminishing returns.

## Notes

- LM Studio has intelligent prompt caching - subsequent runs with similar prompts will be faster
- Restart LM Studio after each patch change for it to take effect
- Results may vary based on model size, quantization, and system load

## License

MIT
