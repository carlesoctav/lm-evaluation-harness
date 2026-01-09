# Evaluation Results Comparison

## Table 1: Non-thinking models (flexible-extract)

| Benchmark | 1b no-think | **4b no-think** |
|-----------|-------------|-----------------|
| **gemma_bbh** | 0.3225 | **0.5276** |
| **gemma_gpqa** | 0.2273 | 0.2273 |
| **gemma_gsm8k** | 0.6005 | **0.8719** |
| **gemma_ifeval** | 0.5619 | **0.7403** |
| **gemma_math500** | 0.4060 | **0.6480** |
| **gemma_mmlu_pro** | 0.1451 | **0.3116** |
| **gemma_zebralogic** | 0.2185 | **0.3461** |

---

## Table 2: Thinking models with NEW PROMPTS (xml-strict-match)

| Benchmark | 1b with-think (new) | **4b with-think (new)** |
|-----------|---------------------|-------------------------|
| **gemma_bbh** | 0.333 | **0.6724** |
| **gemma_gpqa** | 0.2020 | **0.2374** |
| **gemma_gsm8k** | 0.3040 | **0.8423** |
| **gemma_ifeval** | 0.4935 | **0.6636** |
| **gemma_math500** | 0.3360 | **0.6300** |
| **gemma_mmlu_pro** | 0.1274 | **0.3939** |
| **gemma_zebralogic** | 0.0881 | **0.2387** |

---

## Table 3: 4b no-think vs 4b with-think (new-prompt)

| Benchmark | 4b no-think (flex) | 4b with-think (xml-strict) | Winner |
|-----------|--------------------|-----------------------------|--------|
| **gemma_bbh** | 0.5276 | **0.6724** | with-think +27% |
| **gemma_gpqa** | 0.2273 | **0.2374** | with-think +4% |
| **gemma_gsm8k** | **0.8719** | 0.8423 | no-think +4% |
| **gemma_ifeval** | **0.7403** | 0.6636 | no-think +12% |
| **gemma_math500** | **0.6480** | 0.6300 | no-think +3% |
| **gemma_mmlu_pro** | 0.3116 | **0.3939** | with-think +26% |
| **gemma_zebralogic** | **0.3461** | 0.2387 | no-think +45% |

---

## Quality Stats (new-prompt)

| Metric | 1b with-think | 4b no-think | 4b with-think |
|--------|---------------|-------------|---------------|
| Complete format | 7.2% | 0% | **70.8%** |
| Length stops | 6.7% | 0.9% | 5.4% |
| Repetition | 13.0% | **2.0%** | 7.3% |

---

## Key Findings

**1b model struggles with thinking format:**
- Only 7.2% complete format (vs 70.8% for 4b)
- Scores 2-3x lower than 4b across all benchmarks

**4b with new prompts improved massively:**
- GSM8K: 0.51 → 0.84 (+66%)
- Math500: 0.15 → 0.63 (+326%)
- GPQA: 0.18 → 0.24 (+31%)

## Summary

| Use Case | Best Model |
|----------|------------|
| Math (GSM8K, Math500) | **4b no-think** |
| Instruction following (IFEval) | **4b no-think** |
| Logic puzzles (ZebraLogic) | **4b no-think** |
| Complex reasoning (BBH) | **4b with-think** |
| MMLU-Pro, GPQA | **4b with-think** |

---
*Generated: 2026-01-08 (v2 with new prompts)*
