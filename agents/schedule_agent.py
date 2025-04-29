import os
import json
from pathlib import Path
import logging
from dotenv import load_dotenv
from util.language_model import LanguageModel
from prompts.schedule import SCHEDULE_PROMPT
from tools.schedule_tool import SCHEDULE_TOOLS
from util.database import SqlQueryExecutor
from util.helper import Helper

# load environment variable
load_dotenv()

class ScheduleAgent:
    def __init__(self, question: str, message_state: dict = {}):
        self.question = question
        self.llm = LanguageModel()
        self.schedule = None
        self.message_state = message_state
        self.memory = []

    def process_schedule(self) -> dict:
        """
        Process the question to get the schedule information.
        """
        try:
            # Step 1: The prompt for the Agent
            messages = [{"role": "system", "content": SCHEDULE_PROMPT}]

            # Step 2: The user message
            messages.append({"role": "user", "content": self.question})

            # add use message to the message state
            self.memory.append({"role": "user", "content": self.question})

            # Step 3: Call the LLM to get the schedule information
            response = self.llm.generate_response(messages, SCHEDULE_TOOLS)

            # add the response to the message state
            self.memory.append({"role": "assistant", "content": response.choices[0].message.content})

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

                # aggregate the DataFrame
                df = df.sum(axis=0, numeric_only=True).reset_index()

                # convert DataFrame to dictionary
                data = df.to_dict(orient='records')

                # read the metadata file
                metadata = Helper.convert_to_markdown(metadata_file_path)

                # save the data to memory
                self.memory.append({"role": "tool", "name": function_name, "content": json.dumps(tool_arguments)})

                 # Concatenate data and metadata as markdown
                markdown_output = f"### Data\n\n{json.dumps(data, indent=2)}\n\n### Metadata\n\n{metadata}"
                
                output = {
                    "status": "success",
                    "message": "Tool executed successfully.",
                    "response": markdown_output,
                    "context": self.memory,
                }

                return output

        except Exception as e:
            return {"error": str(e)}
        except FileNotFoundError as e:
            return {"File error": str(e)}
        