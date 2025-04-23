import os
import json
import logging
from pathlib import Path
from dotenv import load_dotenv
from util.language_model import LanguageModel
from prompts.answer import ANSWER_PROMPT

# load environment variable
load_dotenv()

class AnswerAgent:
    def __init__(self, question: str, messages: dict = {}):
        self.question = question
        self.messages = messages
        self.llm = LanguageModel()
        self.answer = None
    

    def process_answer(self) -> dict:
        """
        Process the question to get the answer information.
        """
        try:

            # Step 1: Provide Prompt Parameters
            answer_prompt = ANSWER_PROMPT.format(
                question=self.question,
                data=self.messages.get("payload", {}),
                metadata=self.messages.get("metadata", {}),
            )

            # Step 2: The prompt for the Agent
            messages = [{"role": "system", "content": answer_prompt}]

            # Step 3: The user message
            messages.append({"role": "user", "content": self.question})

            # Step 4: Call the LLM to get the answer information
            response = self.llm.generate_response(messages)
            self.answer = response.choices[0].message.content

            return {
                "status": "success",
                "message": "Answer retrieved successfully.",
                "response": self.answer
            }

        except Exception as e:
            return {"error": str(e)}