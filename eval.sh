#!/bin/bash

# Math evaluation script for GSM8K and MATH500 (zero-shot non-CoT)
# Usage: ./math_non_cot.sh --model <model_path>

set -e

# Default values
MODEL=""
DTYPE="bfloat16"
MAX_GEN_TOKS=2048
BATCH_SIZE="auto"
OUTPUT_DIR="results"
PROJECT="lm-eval-harness-integration"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --dtype)
            DTYPE="$2"
            shift 2
            ;;
        --max_gen_toks)
            MAX_GEN_TOKS="$2"
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
        --project)
            PROJECT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./math_non_cot.sh --model <model_path> [--dtype bfloat16] [--max_gen_toks 512] [--batch_size auto] [--output_dir results] [--project lm-eval-harness-integration]"
            exit 1
            ;;
    esac
done

# Check if model is provided
if [ -z "$MODEL" ]; then
    echo "Error: --model is required"
    echo "Usage: ./math_non_cot.sh --model <model_path>"
    exit 1
fi

# Extract model name for output directory
MODEL_NAME=$(basename "$MODEL")
OUTPUT_PATH="${OUTPUT_DIR}/${MODEL_NAME}-no-think"

echo "=========================================="
echo "Math Evaluation (Zero-shot Non-CoT)"
echo "=========================================="
echo "Model: $MODEL"
echo "Tasks: gsm8k, minerva_math500"
echo "Output: $OUTPUT_PATH"
echo "W&B Project: $PROJECT"
echo "=========================================="

lm_eval --model vllm \
    --model_args pretrained="$MODEL" dtype="$DTYPE" max_gen_toks="$MAX_GEN_TOKS" tensor_parallel_size=1 max_model_len=8192 max_num_batched_tokens=2048 \
    --tasks gsm8k minerva_math500 \
    --gen_kwargs temperature=0 \
    --num_fewshot 0 \
    --batch_size "$BATCH_SIZE" \
    --apply_chat_template \
    --log_samples \
    --output_path "$OUTPUT_PATH" \
    --wandb_args project="$PROJECT"

echo "=========================================="
echo "Done! Results saved to: $OUTPUT_PATH"
echo "=========================================="

