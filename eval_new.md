# Evaluation Results (New Prompts with `<answer>` tags)

## Gemma-2-2B-IT with-think (new prompts)

| Benchmark | flexible | xml-match | xml-strict |
|-----------|----------|-----------|------------|
| **gemma_bbh** | 0.1226 | - | - |
| **gemma_gpqa** | 0.2576 | 0.2020 | **0.2525** |
| **gemma_gsm8k** | 0.1372 | 0.0637 | 0.0637 |
| **gemma_ifeval** | 0.4085 | - | - |
| **gemma_math500** | 0.0400 / 0.0420 (equiv) / 0.0800 (verify) | - | - |
| **gemma_mmlu_pro** | 0.1547 | 0.1254 | **0.1614** |
| **gemma_zebralogic** | 0.1841 | 0.1715 | **0.2022** |

### Quality Stats (gemma-2-2b-it)

| Metric | Value |
|--------|-------|
| **`<answer>` present** | 84.3% ✅ |
| **`</answer>` present** | 84.0% ✅ |
| **Complete format** | 22.3% |
| **Repetition** | 10.2% |

---

## Comparison: Gemma-2-2B vs Gemma-3-1B (flexible-extract)

| Benchmark | Gemma-2-2B | Gemma-3-1B |
|-----------|------------|------------|
| **BBH** | 0.12 | 0.39 |
| **GPQA** | 0.26 | 0.24 |
| **GSM8K** | 0.14 | 0.20 |
| **MMLU-Pro** | 0.15 | 0.13 |
| **ZebraLogic** | 0.18 | 0.15 |

**Note:** Gemma-2-2B follows `<answer>` tags much better (84% vs 32%), but scores are generally lower than Gemma-3 series.

---

## Key Finding: xml-strict-match works better on Gemma-2

For Gemma-2-2B, xml-strict-match scores are often **higher** than xml-match:
- GPQA: 0.25 (strict) vs 0.20 (match)
- MMLU-Pro: 0.16 (strict) vs 0.13 (match)
- ZebraLogic: 0.20 (strict) vs 0.17 (match)

---
*Generated: 2026-01-08*
