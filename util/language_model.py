import os
from openai import OpenAI
import logging
import requests
from dotenv import load_dotenv

# load environment variable
load_dotenv()

class LanguageModel:
    def __init__(self):
        self.client = OpenAI(
            api_key=os.getenv('OPENAI_API_KEY') 
        )
        
    def generate_response(self, messages, tools=None):
        try:
            response = self.client.chat.completions.create(
                model=os.getenv('LLM_MODEL'),
                messages=messages,
                tools=tools,
                temperature=0,
            )
            return response
        except Exception as e:
            logging.error(f"An error occurred while generating a response: {e}")
            return Exception(f"An error occurred while generating a response: {e}")
        
