#!/bin/bash

# Evaluation script for gemma-style tasks with tag and length statistics
# Usage: ./eval_with_gemma_final.sh --model <model_name> [options]

set -e

# Default values
MODEL=""
BASE_URL="http://10.130.0.58:8000/v1/chat/completions"
NUM_CONCURRENT=100
BATCH_SIZE=1
OUTPUT_DIR="results"
TASKS="gemma_gsm8k,gemma_gpqa,gemma_mmlu_pro,gemma_ifeval,gemma_zebralogic,gemma_bbh,gemma_math500"

HF_HOME="/mnt/carles/.cache"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --base_url)
            BASE_URL="$2"
            shift 2
            ;;
        --num_concurrent)
            NUM_CONCURRENT="$2"
            shift 2
            ;;
        --batch_size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --output_dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --tasks)
            TASKS="$2"
            shift 2
            ;;
        --hf_home)
            HF_HOME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./eval_with_gemma_final.sh --model <model_name> [options]"
            echo ""
            echo "Options:"
            echo "  --model          Model name on vLLM server (required)"
            echo "  --base_url       vLLM server URL (default: http://localhost:8000/v1/chat/completions)"
            echo "  --num_concurrent Number of concurrent requests (default: 100)"
            echo "  --batch_size     Batch size (default: 1)"
            echo "  --output_dir     Output directory (default: results)"
            echo "  --tasks          Comma-separated tasks (default: all gemma tasks)"
            echo "  --hf_home        HuggingFace cache directory (default: /mnt/carles/.cache)"
            exit 1
            ;;
    esac
done

# Check if model is provided
if [ -z "$MODEL" ]; then
    # Try to get model from vLLM server
    echo "No model specified, checking vLLM server..."
    MODEL=$(curl -s http://localhost:8000/v1/models | python3 -c "import sys, json; print(json.load(sys.stdin)['data'][0]['id'])" 2>/dev/null || echo "")
    if [ -z "$MODEL" ]; then
        echo "Error: --model is required and could not detect model from vLLM server"
        exit 1
    fi
    echo "Detected model: $MODEL"
fi

# Create sanitized model name for output path
MODEL_SANITIZED=$(echo "$MODEL" | tr '/' '__')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_PATH="${OUTPUT_DIR}/${MODEL_SANITIZED}_${TIMESTAMP}"

echo "=============================================="
echo "Gemma-Style Evaluation"
echo "=============================================="
echo "Model: $MODEL"
echo "Base URL: $BASE_URL"
echo "Tasks: $TASKS"
echo "Output: $OUTPUT_PATH"
echo "=============================================="

# Run evaluation
export HF_HOME="$HF_HOME"

.venv/bin/python -m lm_eval \
    --model local-chat-completions \
    --model_args "model=$MODEL,base_url=$BASE_URL,num_concurrent=$NUM_CONCURRENT" \
    --tasks "$TASKS" \
    --include_path tasks \
    --batch_size "$BATCH_SIZE" \
    --apply_chat_template \
    --log_samples \
    --output_path "$OUTPUT_PATH"

echo ""
echo "=============================================="
echo "Evaluation complete! Running statistics..."
echo "=============================================="

# Run statistics analysis
python3 - "$OUTPUT_PATH" << 'PYTHON_SCRIPT'
import json
import glob
import sys
import os

output_path = sys.argv[1] if len(sys.argv) > 1 else ''

# Find sample files
sample_files = sorted(glob.glob(f'{output_path}/**/*samples*.jsonl', recursive=True))

if not sample_files:
    print("No sample files found!")
    sys.exit(1)

print(f"\nFound {len(sample_files)} sample files")
print("=" * 100)

# Collect statistics
total_stats = {
    '<reasoning>': 0,
    '</reasoning>': 0,
    '<answer>': 0,
    '</answer>': 0,
    'total_samples': 0,
    'has_complete_format': 0,
    'likely_length_stop': 0,
}

task_stats = {}

for file in sample_files:
    task = file.split('samples_')[1].split('_202')[0]
    
    stats = {
        '<reasoning>': 0,
        '</reasoning>': 0,
        '<answer>': 0,
        '</answer>': 0,
        'total': 0,
        'has_complete_format': 0,
        'likely_length_stop': 0,
    }
    
    with open(file) as f:
        for line in f:
            data = json.loads(line)
            response = data.get('resps', [[]])[0][0] if data.get('resps') else ''
            
            stats['total'] += 1
            
            has_reasoning_open = '<reasoning>' in response
            has_reasoning_close = '</reasoning>' in response
            has_answer_open = '<answer>' in response
            has_answer_close = '</answer>' in response
            
            if has_reasoning_open:
                stats['<reasoning>'] += 1
            if has_reasoning_close:
                stats['</reasoning>'] += 1
            if has_answer_open:
                stats['<answer>'] += 1
            if has_answer_close:
                stats['</answer>'] += 1
            
            if has_reasoning_open and has_reasoning_close and has_answer_open and has_answer_close:
                stats['has_complete_format'] += 1
            
            # Likely stopped by length: long response AND missing closing tags
            is_long = len(response) > 3500
            if is_long and (not has_answer_close or not has_reasoning_close):
                stats['likely_length_stop'] += 1
    
    task_stats[task] = stats
    
    # Add to totals
    for key in ['<reasoning>', '</reasoning>', '<answer>', '</answer>', 'has_complete_format', 'likely_length_stop']:
        total_stats[key] += stats[key]
    total_stats['total_samples'] += stats['total']

# Print tag statistics
print("\n" + "=" * 100)
print("TAG STATISTICS")
print("=" * 100)
print(f"{'Task':<40} | {'Total':>6} | {'<reas>':>6} | {'</reas>':>7} | {'<ans>':>6} | {'</ans>':>7} | {'Complete':>8} | {'LenStop':>7}")
print("-" * 100)

for task in sorted(task_stats.keys()):
    s = task_stats[task]
    complete_pct = 100 * s['has_complete_format'] / s['total'] if s['total'] > 0 else 0
    len_stop_pct = 100 * s['likely_length_stop'] / s['total'] if s['total'] > 0 else 0
    print(f"{task[:40]:<40} | {s['total']:>6} | {s['<reasoning>']:>6} | {s['</reasoning>']:>7} | {s['<answer>']:>6} | {s['</answer>']:>7} | {complete_pct:>7.1f}% | {len_stop_pct:>6.1f}%")

print("-" * 100)
t = total_stats
complete_pct = 100 * t['has_complete_format'] / t['total_samples']
len_stop_pct = 100 * t['likely_length_stop'] / t['total_samples']
print(f"{'TOTAL':<40} | {t['total_samples']:>6} | {t['<reasoning>']:>6} | {t['</reasoning>']:>7} | {t['<answer>']:>6} | {t['</answer>']:>7} | {complete_pct:>7.1f}% | {len_stop_pct:>6.1f}%")

# Print summary
print("\n" + "=" * 100)
print("SUMMARY")
print("=" * 100)
print(f"Total samples:                    {t['total_samples']:>8}")
print()
print(f"<reasoning> tag present:          {t['<reasoning>']:>8} ({100*t['<reasoning>']/t['total_samples']:>5.1f}%)")
print(f"</reasoning> tag present:         {t['</reasoning>']:>8} ({100*t['</reasoning>']/t['total_samples']:>5.1f}%)")
print(f"<answer> tag present:             {t['<answer>']:>8} ({100*t['<answer>']/t['total_samples']:>5.1f}%)")
print(f"</answer> tag present:            {t['</answer>']:>8} ({100*t['</answer>']/t['total_samples']:>5.1f}%)")
print()
print(f"Complete format (all 4 tags):     {t['has_complete_format']:>8} ({100*t['has_complete_format']/t['total_samples']:>5.1f}%)")
print(f"Likely stopped by length:         {t['likely_length_stop']:>8} ({100*t['likely_length_stop']/t['total_samples']:>5.1f}%)")

# Check for repetition
print("\n" + "=" * 100)
print("REPETITION CHECK")
print("=" * 100)

import re
from collections import Counter

def has_repetition(text, min_len=30, min_repeats=3):
    if len(text) < 500:
        return False
    chunks = re.split(r'[.!?\n]', text)
    chunks = [c.strip() for c in chunks if len(c.strip()) > min_len]
    chunk_counts = Counter(chunks)
    for chunk, count in chunk_counts.items():
        if count >= min_repeats:
            return True
    return False

rep_stats = {}
total_rep = 0
total_samples = 0

for file in sample_files:
    task = file.split('samples_')[1].split('_202')[0]
    rep_count = 0
    task_total = 0
    
    with open(file) as f:
        for line in f:
            data = json.loads(line)
            response = data.get('resps', [[]])[0][0] if data.get('resps') else ''
            task_total += 1
            if has_repetition(response):
                rep_count += 1
    
    rep_stats[task] = (rep_count, task_total)
    total_rep += rep_count
    total_samples += task_total

print(f"{'Task':<40} | {'Repetitions':>12} | {'Total':>8} | {'%':>7}")
print("-" * 75)
for task in sorted(rep_stats.keys()):
    rep, tot = rep_stats[task]
    if rep > 0:
        print(f"{task[:40]:<40} | {rep:>12} | {tot:>8} | {100*rep/tot:>6.1f}%")
print("-" * 75)
print(f"{'TOTAL':<40} | {total_rep:>12} | {total_samples:>8} | {100*total_rep/total_samples:>6.1f}%")

print("\n" + "=" * 100)
print(f"Results saved to: {output_path}")
print("=" * 100)
PYTHON_SCRIPT

echo ""
echo "Done!"
