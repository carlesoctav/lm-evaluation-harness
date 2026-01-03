#!/bin/bash

# OLMo3 Adapt Evaluation - Single Command Version
# Runs all available tasks in one lm_eval call
#
# Usage: ./olmo3_adapt_single.sh --model <model_path> [--limit N] [--apply_chat_template]

set -e

MODEL=""
DTYPE="bfloat16"
MAX_GEN_TOKS=4096
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
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

if [ -z "$MODEL" ]; then
    echo "Usage: ./olmo3_adapt_single.sh --model <model_path> [--tp 4] [--limit N] [--apply_chat_template]"
    exit 1
fi

MODEL_NAME=$(basename "$MODEL")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_PATH="${OUTPUT_DIR}/${MODEL_NAME}_olmo3_adapt_${TIMESTAMP}"

# All available tasks that map to olmo3:adapt:noapi
# Some olmes tasks don't have direct lm_eval equivalents
TASKS="mmlu,bbh_cot_zeroshot,gpqa_diamond_cot_zeroshot,gsm8k_cot,minerva_math,aime24,aime25,humaneval_plus,mbpp_plus,ifeval"

echo "==========================================="
echo "OLMo3 Adapt Evaluation (Single Command)"
echo "==========================================="
echo "Model: $MODEL"
echo "Tasks: $TASKS"
echo "Output: $OUTPUT_PATH"
echo "==========================================="

lm_eval run --model vllm \
    --model_args "pretrained=$MODEL,dtype=$DTYPE,max_gen_toks=$MAX_GEN_TOKS,tensor_parallel_size=$TENSOR_PARALLEL_SIZE,max_model_len=$MAX_MODEL_LEN" \
    --tasks "$TASKS" \
    --num_fewshot 0 \
    --gen_kwargs "temperature=0.6,top_p=0.95,do_sample=True" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "$OUTPUT_PATH"

echo ""
echo "Done! Results: $OUTPUT_PATH"
