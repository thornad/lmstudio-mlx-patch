#!/usr/bin/env python3
"""
MLX Prefill Benchmark Script

Measures prompt processing (prefill) time for different chunk sizes.
Uses mlx_lm library directly for accurate timing.

Usage:
    python benchmark_prefill.py --model <model_path> --runs 3
"""

import argparse
import time
import json
from pathlib import Path

import mlx.core as mx
from mlx_lm import load, generate
from mlx_lm.tokenizer_utils import load_tokenizer


def load_prompt(prompt_file: str) -> str:
    """Load the benchmark prompt from file."""
    with open(prompt_file, "r") as f:
        return f.read()


def count_tokens(tokenizer, text: str) -> int:
    """Count tokens in text."""
    return len(tokenizer.encode(text))


def benchmark_prefill(model, tokenizer, prompt: str, max_tokens: int = 1) -> dict:
    """
    Benchmark prefill time by generating just 1 token.

    The time to first token is essentially the prefill time.
    """
    # Ensure any previous computation is done
    mx.eval(model.parameters())

    # Tokenize prompt
    tokens = tokenizer.encode(prompt)
    prompt_tokens = len(tokens)

    # Warm up (optional, first run may be slower)
    # generate(model, tokenizer, prompt="Hello", max_tokens=1, verbose=False)

    # Time the generation of first token (which requires full prefill)
    start_time = time.perf_counter()

    # Generate just 1 token - this forces complete prefill
    output = generate(
        model,
        tokenizer,
        prompt=prompt,
        max_tokens=max_tokens,
        verbose=False,
    )

    end_time = time.perf_counter()

    elapsed = end_time - start_time
    tokens_per_second = prompt_tokens / elapsed

    return {
        "prompt_tokens": prompt_tokens,
        "elapsed_seconds": elapsed,
        "tokens_per_second": tokens_per_second,
    }


def run_benchmark(model_path: str, prompt_file: str, num_runs: int = 3) -> list:
    """Run benchmark multiple times and collect results."""

    print(f"\n{'='*60}")
    print(f"Loading model: {model_path}")
    print(f"{'='*60}")

    # Load model and tokenizer
    model, tokenizer = load(model_path)

    # Load prompt
    prompt = load_prompt(prompt_file)
    token_count = count_tokens(tokenizer, prompt)

    print(f"Prompt tokens: {token_count:,}")
    print(f"Running {num_runs} iterations...")
    print()

    results = []

    for i in range(num_runs):
        print(f"  Run {i+1}/{num_runs}...", end=" ", flush=True)

        result = benchmark_prefill(model, tokenizer, prompt)
        results.append(result)

        print(f"Time: {result['elapsed_seconds']:.2f}s, "
              f"Speed: {result['tokens_per_second']:.0f} tok/s")

    # Calculate statistics
    times = [r["elapsed_seconds"] for r in results]
    speeds = [r["tokens_per_second"] for r in results]

    avg_time = sum(times) / len(times)
    min_time = min(times)
    max_time = max(times)
    variance = max_time - min_time

    avg_speed = sum(speeds) / len(speeds)

    print()
    print(f"  Summary:")
    print(f"    Avg time:  {avg_time:.2f}s")
    print(f"    Min time:  {min_time:.2f}s")
    print(f"    Max time:  {max_time:.2f}s")
    print(f"    Variance:  {variance:.2f}s")
    print(f"    Avg speed: {avg_speed:.0f} tok/s")

    return {
        "model": model_path,
        "prompt_tokens": token_count,
        "runs": results,
        "summary": {
            "avg_time": avg_time,
            "min_time": min_time,
            "max_time": max_time,
            "variance": variance,
            "avg_speed": avg_speed,
        }
    }


def main():
    parser = argparse.ArgumentParser(description="MLX Prefill Benchmark")
    parser.add_argument("--model", required=True, help="Path to MLX model")
    parser.add_argument("--prompt", default="benchmark_40k.txt", help="Prompt file")
    parser.add_argument("--runs", type=int, default=3, help="Number of runs")
    parser.add_argument("--output", help="Output JSON file for results")

    args = parser.parse_args()

    # Resolve prompt file path
    script_dir = Path(__file__).parent
    prompt_file = script_dir / args.prompt

    if not prompt_file.exists():
        print(f"Error: Prompt file not found: {prompt_file}")
        return 1

    # Run benchmark
    results = run_benchmark(args.model, str(prompt_file), args.runs)

    # Save results if output specified
    if args.output:
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to: {args.output}")

    return 0


if __name__ == "__main__":
    exit(main())
