#!/usr/bin/env python3
"""
LM Studio API Benchmark - measures Time to First Token (TTFT)
Uses non-streaming API for reliable timing.
"""
import requests
import time
import json
import sys
import random
import string

def benchmark(prompt_file: str, model: str, runs: int = 1):
    with open(prompt_file, 'r') as f:
        base_prompt = f.read()
    
    results = []
    
    for i in range(runs):
        # Add random suffix to prevent caching
        random_id = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
        prompt = base_prompt + f"\n[Session: {random_id}] Reply with just OK."
        
        data = {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 5,
            "stream": False
        }
        
        print(f"Run {i+1}/{runs}...", end=" ", flush=True)
        
        start = time.perf_counter()
        response = requests.post(
            "http://localhost:1234/v1/chat/completions",
            headers={"Content-Type": "application/json"},
            json=data,
            timeout=1800
        )
        elapsed = time.perf_counter() - start
        
        result = response.json()
        tokens = result.get("usage", {}).get("prompt_tokens", 0)
        speed = tokens / elapsed if elapsed > 0 else 0
        
        print(f"{elapsed:.0f}s | {tokens} tokens | {speed:.0f} tok/s")
        results.append({"time": elapsed, "tokens": tokens, "speed": speed})
    
    if runs > 1:
        avg_speed = sum(r["speed"] for r in results) / len(results)
        print(f"\nAverage: {avg_speed:.0f} tok/s")
    
    return results

if __name__ == "__main__":
    prompt_file = sys.argv[1] if len(sys.argv) > 1 else "benchmark_40k.txt"
    model = sys.argv[2] if len(sys.argv) > 2 else "glm-4.7-v4-fast"
    runs = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    
    print(f"Model: {model}")
    print(f"Prompt: {prompt_file}")
    print(f"Runs: {runs}")
    print()
    
    benchmark(prompt_file, model, runs)
