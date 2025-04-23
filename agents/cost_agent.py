import os
import json
from pathlib import Path
import logging
from dotenv import load_dotenv
from util.language_model import LanguageModel
from prompts.cost import COST_PROMPT
from tools.cost_tool import COST_TOOLS
from util.database import SqlQueryExecutor
from util import helper

# load environment variable
load_dotenv()

class CostAgent:
    def __init__(self, question: str, message_state: dict = {}):
        self.question = question
        self.llm = LanguageModel()
        self.cost = None
        self.message_state = message_state

    def process_cost(self) -> dict:
        """
        Process the question to get the cost information.
        """
        try:
            # Step 1: The prompt for the Agent
            messages = [{"role": "system", "content": COST_PROMPT}]

            # Step 2: The user message
            messages.append({"role": "user", "content": self.question})

            # Step 3: Call the LLM to get the cost information
            response = self.llm.generate_response(messages, COST_TOOLS)

            # Step 4: Check if the response contains tool calls
            if response.choices[0].message.tool_calls:
                return self.execute_tool(response)
            else:
                return {
                    "status": "error",
                    "message": "No tool calls found in the response.",
                    "response": response.choices[0].message.content
                }

        except Exception as e:
            return {"error": str(e)}
        
    def execute_tool(self, model_response: any) -> dict:
        """
        Execute the specified tool with the given parameters.
        """
        try:
            # Step 1: Extract the function name and parameters from the response
            for tool_call in model_response.choices[0].message.tool_calls:
                
                function_name = tool_call.function.name
                tool_arguments = json.loads(tool_call.function.arguments)
                params = tuple(tool_arguments.values())

                # sql file path
                sql_file_path = f"data/sql/{function_name.split('_', 1)[0]}.sql"
                if not os.path.exists(sql_file_path):
                    raise FileNotFoundError(f"SQL file {sql_file_path} not found.")
                else:
                    sql_file_path = Path(sql_file_path)

                # metadata file path
                metadata_file_path = f"data/metadata/{function_name.split('_', 1)[0]}.docx"
                if not os.path.exists(metadata_file_path):
                    raise FileNotFoundError(f"Metadata file {metadata_file_path} not found.")
                else:
                    metadata_file_path = Path(metadata_file_path)

                # implement SQL query execution
                queryExecutor = SqlQueryExecutor()
                df = queryExecutor.execute_query_from_file(sql_file_path, params)

                # convert DataFrame to dictionary
                data = df.to_dict(orient='records')

                # read the metadata file
                metadata = helper.convert_to_markdown(metadata_file_path)

                # Step 2: Update the message state with the tool execution result
                # self.message_state.append({"role": "tool", "name": function_name, "content": json.dumps(data)})

                # Step 2: Return the data as a JSON response
                output = {
                    "question": self.question,
                    "status": "success",
                    "message": "Tool executed successfully.",
                    "tool_name": function_name,
                    "payload": data,
                    "next_agent": "answer_agent",
                    "metadata": metadata
                }

                return output

        except Exception as e:
            return {"error": str(e)}