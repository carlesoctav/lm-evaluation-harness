#!/bin/bash

# OLMo3 Minimal Prompt Evaluation Suite
# Full suite matching olmo3:adapt:noapi from olmes
# All generate_until with minimal prompts (just question)
#
# Usage: ./olmo3_minimal.sh --model <model_path> [options]

set -e

MODEL=""
DTYPE="bfloat16"
BATCH_SIZE="auto"
OUTPUT_DIR="results"
TENSOR_PARALLEL_SIZE=4
MAX_MODEL_LEN=8192
LIMIT=""
APPLY_CHAT_TEMPLATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --model) MODEL="$2"; shift 2 ;;
        --dtype) DTYPE="$2"; shift 2 ;;
        --tp) TENSOR_PARALLEL_SIZE="$2"; shift 2 ;;
        --max_model_len) MAX_MODEL_LEN="$2"; shift 2 ;;
        --limit) LIMIT="--limit $2"; shift 2 ;;
        --apply_chat_template) APPLY_CHAT_TEMPLATE="--apply_chat_template"; shift ;;
        --output_dir) OUTPUT_DIR="$2"; shift 2 ;;
        --batch_size) BATCH_SIZE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ./olmo3_minimal.sh --model <model_path> [options]"
            echo ""
            echo "Options:"
            echo "  --model              Model path (required)"
            echo "  --dtype              Data type (default: bfloat16)"
            echo "  --tp                 Tensor parallel size (default: 4)"
            echo "  --max_model_len      Max model length (default: 8192)"
            echo "  --limit              Limit examples per task"
            echo "  --apply_chat_template Apply chat template"
            echo "  --output_dir         Output directory (default: results)"
            echo "  --batch_size         Batch size (default: auto)"
            echo ""
            echo "Tasks (14 total):"
            echo "  Knowledge: mmlu, popqa"
            echo "  Reasoning: bbh, gpqa, zebralogic, agieval_en"
            echo "  Math: gsm8k, math, omega, aime (2024+2025)"
            echo "  Coding: humaneval, mbpp, livecodebench"
            echo "  IF: ifeval"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$MODEL" ]; then
    echo "Error: --model is required"
    exit 1
fi

# Enable code execution for humaneval/mbpp/livecodebench
export HF_ALLOW_CODE_EVAL="1"

MODEL_NAME=$(basename "$MODEL")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_PATH="${OUTPUT_DIR}/${MODEL_NAME}_olmo3_minimal_${TIMESTAMP}"

echo "==========================================="
echo "OLMo3 Minimal Prompt Evaluation"
echo "==========================================="
echo "Model: $MODEL"
echo "Output: $OUTPUT_PATH"
echo "TP: $TENSOR_PARALLEL_SIZE"
echo ""
echo "Tasks (14):"
echo "  Knowledge: mmlu, popqa"
echo "  Reasoning: bbh, gpqa, zebralogic, agieval_en"
echo "  Math: gsm8k, math, omega, aime24, aime25"
echo "  Coding: humaneval, mbpp, livecodebench"
echo "  IF: ifeval"
echo "==========================================="

lm_eval run --model vllm \
    --model_args "pretrained=$MODEL,dtype=$DTYPE,tensor_parallel_size=$TENSOR_PARALLEL_SIZE,max_model_len=$MAX_MODEL_LEN" \
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
