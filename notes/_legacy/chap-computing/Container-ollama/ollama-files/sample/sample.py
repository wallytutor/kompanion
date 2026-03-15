# -*- coding: utf-8 -*-
from PyPDF2 import PdfReader
import ollama

reader = PdfReader("sample.pdf")
content = "\n".join(page.extract_text() for page in reader.pages)

resp = ollama.chat(model="llama3.1:8b", messages=[
    {
        "role": "user",
        "content": f"Summarize the following: {content}."
    }
])

print(resp["message"]["content"])
