#!/bin/bash

# OLMo3 Adapt Evaluation Suite (No API/LLM Judge)
# This script runs the equivalent of olmes olmo3:adapt:noapi suite using pure lm_eval
# 
# Tasks included:
# - Knowledge: MMLU (CoT), PopQA
# - Reasoning: BBH (CoT), GPQA, AGI-Eval
# - Math: MATH (Minerva), GSM8K, AIME 2024/2025
# - Coding: HumanEval+, MBPP+
# - Chat/IF: IFEval
#
# Excluded (require API/LLM judge):
# - SimpleQA
# - AlpacaEval

set -e

# Default values
MODEL=""
DTYPE="bfloat16"
MAX_GEN_TOKS=4096
BATCH_SIZE="auto"
OUTPUT_DIR="results"
PROJECT="olmo3-adapt-eval"
TENSOR_PARALLEL_SIZE=4
MAX_MODEL_LEN=8192
LIMIT=""
APPLY_CHAT_TEMPLATE=""

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
        --tp)
            TENSOR_PARALLEL_SIZE="$2"
            shift 2
            ;;
        --max_model_len)
            MAX_MODEL_LEN="$2"
            shift 2
            ;;
        --limit)
            LIMIT="--limit $2"
            shift 2
            ;;
        --apply_chat_template)
            APPLY_CHAT_TEMPLATE="--apply_chat_template"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./olmo3_adapt_noapi.sh --model <model_path> [options]"
            echo ""
            echo "Options:"
            echo "  --model              Model path (required)"
            echo "  --dtype              Data type (default: bfloat16)"
            echo "  --max_gen_toks       Max generation tokens (default: 4096)"
            echo "  --batch_size         Batch size (default: auto)"
            echo "  --output_dir         Output directory (default: results)"
            echo "  --project            W&B project name (default: olmo3-adapt-eval)"
            echo "  --tp                 Tensor parallel size (default: 4)"
            echo "  --max_model_len      Max model length (default: 8192)"
            echo "  --limit              Limit number of examples per task"
            echo "  --apply_chat_template Apply chat template"
            exit 1
            ;;
    esac
done

# Check if model is provided
if [ -z "$MODEL" ]; then
    echo "Error: --model is required"
    exit 1
fi

# Extract model name for output directory
MODEL_NAME=$(basename "$MODEL")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_PATH="${OUTPUT_DIR}/${MODEL_NAME}_olmo3_adapt_${TIMESTAMP}"

echo "==========================================="
echo "OLMo3 Adapt Evaluation Suite (No API)"
echo "==========================================="
echo "Model: $MODEL"
echo "Output: $OUTPUT_PATH"
echo "Tensor Parallel Size: $TENSOR_PARALLEL_SIZE"
echo "==========================================="

# Common model args
MODEL_ARGS="pretrained=$MODEL,dtype=$DTYPE,max_gen_toks=$MAX_GEN_TOKS,tensor_parallel_size=$TENSOR_PARALLEL_SIZE,max_model_len=$MAX_MODEL_LEN"

# Generation kwargs for CoT style (matching olmo3:adapt settings)
# temperature=0.6, top_p=0.95
GEN_KWARGS="temperature=0.6,top_p=0.95,do_sample=True"

mkdir -p "$OUTPUT_PATH"

# ============================================
# 1. Knowledge Tasks
# ============================================

echo ""
echo "[1/7] Running MMLU (Chain-of-Thought)..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks mmlu \
    --num_fewshot 0 \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/mmlu"

# Note: PopQA is not in standard lm_eval, would need custom task
# echo "[1b/7] Running PopQA..."
# PopQA would need to be added as a custom task

# ============================================
# 2. Reasoning Tasks
# ============================================

echo ""
echo "[2/7] Running BBH (Chain-of-Thought)..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks bbh_cot_zeroshot \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/bbh"

echo ""
echo "[3/7] Running GPQA..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks gpqa_diamond_cot_zeroshot \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/gpqa"

# Note: ZebraLogic and AGI-Eval English would need custom tasks
# They are not in standard lm_eval

# ============================================
# 3. Math Tasks
# ============================================

echo ""
echo "[4/7] Running GSM8K..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks gsm8k_cot \
    --num_fewshot 0 \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/gsm8k"

echo ""
echo "[5/7] Running Minerva MATH..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks minerva_math \
    --num_fewshot 0 \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/minerva_math"

echo ""
echo "[5b/7] Running AIME 2024 & 2025..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks aime24,aime25 \
    --num_fewshot 0 \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/aime"

# ============================================
# 4. Coding Tasks
# ============================================

echo ""
echo "[6/7] Running HumanEval+ and MBPP+..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks humaneval_plus,mbpp_plus \
    --num_fewshot 0 \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/code"

# Note: LiveCodeBench would need custom task

# ============================================
# 5. Instruction Following
# ============================================

echo ""
echo "[7/7] Running IFEval..."
lm_eval run --model vllm \
    --model_args "$MODEL_ARGS" \
    --tasks ifeval \
    --num_fewshot 0 \
    --gen_kwargs "$GEN_KWARGS" \
    --batch_size "$BATCH_SIZE" \
    $APPLY_CHAT_TEMPLATE \
    $LIMIT \
    --log_samples \
    --output_path "${OUTPUT_PATH}/ifeval"

echo ""
echo "==========================================="
echo "Evaluation Complete!"
echo "Results saved to: $OUTPUT_PATH"
echo "==========================================="
echo ""
echo "Tasks completed:"
echo "  ✓ MMLU (CoT)"
echo "  ✓ BBH (CoT)"
echo "  ✓ GPQA Diamond (CoT)"
echo "  ✓ GSM8K (CoT)"
echo "  ✓ Minerva MATH"
echo "  ✓ AIME 2024 & 2025"
echo "  ✓ HumanEval+"
echo "  ✓ MBPP+"
echo "  ✓ IFEval"
echo ""
echo "Tasks not available in standard lm_eval (would need custom tasks):"
echo "  - PopQA"
echo "  - ZebraLogic"
echo "  - AGI-Eval English"
echo "  - Omega"
echo "  - LiveCodeBench"
echo ""
