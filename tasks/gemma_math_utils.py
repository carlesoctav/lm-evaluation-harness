import logging
import re
import signal
from typing import Optional

eval_logger = logging.getLogger(__name__)

try:
    import sympy
    from math_verify import parse, verify
    from sympy.parsing.latex import parse_latex
except (ModuleNotFoundError, AssertionError) as e:
    eval_logger.warning(
        "math_verify or sympy not available. Install via: pip install lm-eval[math]"
    )
    parse = None
    verify = None
    parse_latex = None
    sympy = None


class timeout:
    def __init__(self, seconds=1, error_message="Timeout"):
        self.seconds = seconds
        self.error_message = error_message

    def handle_timeout(self, signum, frame):
        raise TimeoutError(self.error_message)

    def __enter__(self):
        signal.signal(signal.SIGALRM, self.handle_timeout)
        signal.alarm(self.seconds)

    def __exit__(self, type, value, traceback):
        signal.alarm(0)


SUBSTITUTIONS = [
    ("an ", ""),
    ("a ", ""),
    (".$", "$"),
    ("\\$", ""),
    (r"\ ", ""),
    (" ", ""),
    ("mbox", "text"),
    (",\\text{and}", ","),
    ("\\text{and}", ","),
    ("\\text{m}", "\\text{}"),
]

REMOVED_EXPRESSIONS = [
    "square", "ways", "integers", "dollars", "mph", "inches", "ft", "hours",
    "km", "units", "\\ldots", "sue", "points", "feet", "minutes", "digits",
    "cents", "degrees", "cm", "gm", "pounds", "meters", "meals", "edges",
    "students", "childrentickets", "multiples", "\\text{s}", "\\text{.}",
    "\\text{\ns}", "\\text{}^2", "\\text{}^3", "\\text{\n}", "\\text{}",
    r"\mathrm{th}", r"^\circ", r"^{\circ}", r"\;", r",\!", "{,}", '"', "\\dots",
]


def normalize_final_answer(final_answer: str) -> str:
    """Normalize a final answer to a quantitative reasoning question."""
    final_answer = final_answer.split("=")[-1]

    for before, after in SUBSTITUTIONS:
        final_answer = final_answer.replace(before, after)
    for expr in REMOVED_EXPRESSIONS:
        final_answer = final_answer.replace(expr, "")

    # Extract answer that is in LaTeX math, is bold, is surrounded by a box, etc.
    final_answer = re.sub(r"(.*?)(\$)(.*?)(\$)(.*)", "$\\3$", final_answer)
    final_answer = re.sub(r"(\\text\{)(.*?)(\})", "\\2", final_answer)
    final_answer = re.sub(r"(\\textbf\{)(.*?)(\})", "\\2", final_answer)
    final_answer = re.sub(r"(\\overline\{)(.*?)(\})", "\\2", final_answer)
    final_answer = re.sub(r"(\\boxed\{)(.*)(\\})", "\\2", final_answer)

    # Normalize shorthand TeX
    final_answer = re.sub(r"(frac)([^{])(.)", "frac{\\2}{\\3}", final_answer)
    final_answer = re.sub(r"(sqrt)([^{])", "sqrt{\\2}", final_answer)
    final_answer = final_answer.replace("$", "")

    # Normalize 100,000 -> 100000
    if final_answer.replace(",", "").isdigit():
        final_answer = final_answer.replace(",", "")

    return final_answer


def last_boxed_only_string(string: str) -> Optional[str]:
    """Extract the last \\boxed{} content from a string."""
    idx = string.rfind("\\boxed")
    if "\\boxed " in string:
        return "\\boxed " + string.split("\\boxed ")[-1].split("$")[0]
    if idx < 0:
        idx = string.rfind("\\fbox")
        if idx < 0:
            return None

    i = idx
    right_brace_idx = None
    num_left_braces_open = 0
    while i < len(string):
        if string[i] == "{":
            num_left_braces_open += 1
        if string[i] == "}":
            num_left_braces_open -= 1
            if num_left_braces_open == 0:
                right_brace_idx = i
                break
        i += 1

    if right_brace_idx is None:
        return None
    return string[idx : right_brace_idx + 1]


def remove_boxed(s: str) -> str:
    """Remove \\boxed{} wrapper from a string."""
    if s is None:
        return ""
    if "\\boxed " in s:
        left = "\\boxed "
        if s[: len(left)] == left:
            return s[len(left) :]
    left = "\\boxed{"
    if s.startswith(left) and s.endswith("}"):
        return s[len(left) : -1]
    return s


def is_equiv(x1: str, x2: str) -> bool:
    """Check if two normalized latex strings are mathematically equivalent."""
    if sympy is None or parse_latex is None:
        return x1.strip() == x2.strip()
    
    try:
        with timeout(seconds=5):
            try:
                parsed_x1 = parse_latex(x1)
                parsed_x2 = parse_latex(x2)
            except Exception:
                eval_logger.debug(f"couldn't parse one of {x1} or {x2}")
                return False

            try:
                diff = parsed_x1 - parsed_x2
            except TypeError:
                eval_logger.debug(f"couldn't subtract {x1} and {x2}")
                return False

            try:
                if sympy.simplify(diff) == 0:
                    return True
                else:
                    return False
            except ValueError:
                eval_logger.debug(f"Had trouble simplifying when comparing {x1} and {x2}")
    except TimeoutError:
        eval_logger.debug(f"Timed out comparing {x1} and {x2}")
        return False
    except Exception as e:
        eval_logger.debug(f"Failed comparing {x1} and {x2} with {e}")
        return False
    return False


def extract_answer_from_response(response: str) -> str:
    """Extract answer from response - tries <answer> tags first, then \\boxed{}."""
    # Try <answer> tags first
    answer_match = re.search(r"<answer>([\s\S]*?)</answer>", response)
    if answer_match:
        answer_content = answer_match.group(1).strip()
        # Check if there's a boxed inside
        boxed = last_boxed_only_string(answer_content)
        if boxed:
            return remove_boxed(boxed)
        return answer_content
    
    # Try non-closed <answer> tag
    answer_match = re.search(r"<answer>([\s\S]*)", response)
    if answer_match:
        answer_content = answer_match.group(1).strip()
        boxed = last_boxed_only_string(answer_content)
        if boxed:
            return remove_boxed(boxed)
        return answer_content
    
    # Fall back to boxed
    boxed = last_boxed_only_string(response)
    if boxed:
        return remove_boxed(boxed)
    
    return ""


def process_results(doc: dict, results: list[str]) -> dict[str, int]:
    """Process results with math equivalence checking."""
    response = results[0]
    
    # Extract and normalize the model's answer
    extracted = extract_answer_from_response(response)
    normalized_answer = normalize_final_answer(extracted)
    
    # Get the ground truth
    ground_truth = doc.get("answer", "")
    normalized_ground_truth = normalize_final_answer(ground_truth)
    
    # Check exact match after normalization
    exact = 1 if normalized_answer.strip() == normalized_ground_truth.strip() else 0
    
    # Check mathematical equivalence
    equiv = 1 if is_equiv(normalized_answer, normalized_ground_truth) else 0
    
    # Use math_verify if available
    math_val = 0
    if verify is not None and parse is not None:
        try:
            gold_parsed = parse(doc.get("answer", ""))
            target_parsed = parse(response)
            if verify(gold=gold_parsed, target=target_parsed):
                math_val = 1
        except Exception as e:
            eval_logger.debug(f"math_verify failed: {e}")
    
    return {
        "exact_match": exact,
        "math_equiv": equiv,
        "math_verify": math_val,
    }
