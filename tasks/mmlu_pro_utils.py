import string


def doc_to_text(doc):
    text = f"{doc['question']}\n"
    for i, option in enumerate(doc["options"]):
        text += f"{string.ascii_uppercase[i]}. {option}\n"
    text += "\nPut your answer in <answer>X</answer> where X is your answer letter."
    return text
