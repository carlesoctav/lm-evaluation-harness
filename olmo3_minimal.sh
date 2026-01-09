#!/bin/bash

# OLMo3 Minimal Prompt Evaluation Suite
# Full suite matching olmo3:adapt:noapi from olmes
# All generate_until with minimal prompts (just question)
#
# Usage: ./olmo3_minimal.sh --model <model_name> [options]
#
# Requires: vLLM server running at --base_url (default: http://localhost:8000)
#   Start with: vllm serve <model_path> --port 8000

set -e

# HuggingFace cache directory
export HF_HOME="${HF_HOME:-/mnt/carles/.cache}"

MODEL=""
BASE_URL="http://localhost:8000"
BATCH_SIZE="1"
OUTPUT_DIR="results"
LIMIT=""
APPLY_CHAT_TEMPLATE=""
NUM_CONCURRENT=32

while [[ $# -gt 0 ]]; do
    case $1 in
        --model) MODEL="$2"; shift 2 ;;
        --base_url) BASE_URL="$2"; shift 2 ;;
        --limit) LIMIT="--limit $2"; shift 2 ;;
        --apply_chat_template) APPLY_CHAT_TEMPLATE="--apply_chat_template"; shift ;;
        --output_dir) OUTPUT_DIR="$2"; shift 2 ;;
        --batch_size) BATCH_SIZE="$2"; shift 2 ;;
        --num_concurrent) NUM_CONCURRENT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ./olmo3_minimal.sh --model <model_name> [options]"
            echo ""
            echo "Requires vLLM server running at --base_url"
            echo ""
            echo "Options:"
            echo "  --model              Model name as served by vLLM (required)"
            echo "  --base_url           vLLM server URL (default: http://localhost:8000)"
            echo "  --limit              Limit examples per task"
            echo "  --apply_chat_template Apply chat template"
            echo "  --output_dir         Output directory (default: results)"
            echo "  --batch_size         Batch size (default: 1)"
            echo "  --num_concurrent     Concurrent API requests (default: 32)"
            echo ""
            echo "Tasks (enabled):"
            echo "  Knowledge: mmlu, popqa"
            echo "  Reasoning: bbh, gpqa, zebralogic, agieval_en"
            echo "  Math: gsm8k, aime (2024+2025)"
            echo "  IF: ifeval"
            echo ""
            echo "Tasks (disabled - need code execution):"
            echo "  Coding: humaneval, mbpp, livecodebench"
            echo "  Math: math, omega"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$MODEL" ]; then
    echo "Error: --model is required"
    echo "Hint: Use the model name as served by vLLM (check: curl $BASE_URL/v1/models)"
    exit 1
fi

MODEL_NAME=$(echo "$MODEL" | tr '/' '_')
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_PATH="${OUTPUT_DIR}/${MODEL_NAME}_olmo3_minimal_${TIMESTAMP}"

echo "==========================================="
echo "OLMo3 Minimal Prompt Evaluation"
echo "==========================================="
echo "Model: $MODEL"
echo "Base URL: $BASE_URL"
echo "Output: $OUTPUT_PATH"
echo "Concurrent requests: $NUM_CONCURRENT"
echo ""
echo "Tasks:"
echo "  Knowledge: mmlu, popqa"
echo "  Reasoning: bbh, gpqa, zebralogic, agieval"
echo "  Math: gsm8k, aime24, aime25"
echo "  IF: ifeval"
echo "==========================================="

lm_eval run --model local-chat-completions \
    --model_args "model=$MODEL,base_url=$BASE_URL/v1/chat/completions,num_concurrent=$NUM_CONCURRENT" \
    --tasks olmo3_minimal \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "$OUTPUT_PATH"

echo ""
echo "==========================================="
echo "Done! Results: $OUTPUT_PATH"
echo "==========================================="
