from abc import ABC, abstractmethod
import ast
import os
import json
from util.language_model import LanguageModel
from prompts.agent import AGENT_PROMPT
from tools.base_tool import Tool
from dotenv import load_dotenv

# load environment variable
load_dotenv()

class Agent:
    def __init__(self, name: str, description: str, tools: list[Tool]):
        self.memory = []
        self.name = name.lower()
        self.description = description
        self.tools = tools
        self.model = LanguageModel()
        self.max_memory = 10
        self.system_prompt = AGENT_PROMPT


    def json_parser(self, input_string: str):
        """
        Parse the input string to a dictionary.
        """
        try:
            # Step 1: Convert the string to a dictionary
            parsed_dict = ast.literal_eval(input_string)

            # Step 2: Convert the dictionary to a JSON string
            json_string = json.dumps(parsed_dict)

            # Step 3: Convert the JSON string back to a dictionary
            json_dict = json.loads(json_string)

            if isinstance(json_dict, dict) or isinstance(json_dict, list):
                return json_dict

        except (SyntaxError, ValueError) as e:
            return {"Agent Json parser error": str(e)}
        

    def run(self, user_input: str) -> dict:
        """
        Run the agent with the given user input.
        """
        try:
            self.memory.append({"role": "user", "content": user_input})

            context = "\n".join(self.memory)

            tool_descriptions = "\n".join([f"- {tool.name()}: {tool.description()}" 
                                           for tool in self.tools])
            
            response_format = {"action": "", "args":""}

            prompt = self.system_prompt.format(
                context=context,
                tool_descriptions=tool_descriptions,
                response_format=response_format
            )
            
            response = self.model.generate_response(prompt)
            self.memory.append({
                "role": "assistant", 
                "content": response.choices[0].message.content.strip()
            })

            response_dict = self.json_parser(response)

            # check if any tool can handle the input
            for tool in self.tools:
                if tool.name().lower() == response_dict["action"].lower():
                    tool_response = tool.use(response_dict["args"])
                    self.memory.append({
                        "role": "tool", 
                        "content": tool_response
                    })
                    return {
                        "status": "success",
                        "message": "Tool executed successfully.",
                        "response": tool_response,
                        "payload": [],
                        "conversations": self.memory,
                    }

        except Exception as e:
            return {"Agent run error": str(e)}