import os
import json
from dotenv import load_dotenv
from util.language_model import LanguageModel
from prompts.intent import INTENT_PROMPT
from tools.intent_tool import INTENT_TOOLS
from agents.schedule_agent import ScheduleAgent
from agents.cost_agent import CostAgent
from agents.answer_agent import AnswerAgent


# load environment variable
load_dotenv()

class IntentAgent:
    def __init__(self, question: str):
        self.question = question
        self.llm = LanguageModel()
        self.intent = None
        self.message_state = {}

    def process_intent(self) -> dict:
        """
        Process the question to identify the intent and parameters.
        """
        try:
            # Step 1: The prompt for the Agent
            messages = [{"role": "system", "content": INTENT_PROMPT}]

            # Step 2: The user message
            messages.append({"role": "user", "content": self.question})

            # Step 3: Call the LLM to get the intent and parameters
            response = self.llm.generate_response(messages, INTENT_TOOLS)

            # Step 4: Update the message state
            self.message_state = {
                "question": self.question,
                "status": "success",
                "message": "Intent identified successfully.",
                "response": response.choices[0].message.content,
                "payload": []
            }

            # Step 5: Store the conversation history
            if "conversations" not in self.message_state:
                self.message_state["conversations"] = []
            self.message_state["conversations"].append(messages)

            # Step 4: Check if the response contains tool calls
            if response.choices[0].message.tool_calls:
                return self.route_to_agent(response)
            else:
                return {
                    "question": self.question,
                    "status": "error",
                    "message": "No tool calls found in the response.",
                    "response": response.choices[0].message.content,
                    "payload": [],
                    "conversations": [],
                }

        except Exception as e:
            return {"error": str(e)}
        
    
    def route_to_agent(self, response) -> dict:
        """
        Route the question to the appropriate agent based on the intent.
        """
        try:
            if response.choices[0].message.tool_calls[0].function.name == "send_query_to_agents":
                
                # Extract the function name and parameters from the response
                agent = json.loads(response.choices[0].message.tool_calls[0].function.arguments)["agents"][0]
                query = json.loads(response.choices[0].message.tool_calls[0].function.arguments)["query"]

                # process the schedule agent response
                isProcessing = True

                while isProcessing:
                    if agent == "schedule_agent":
                        # Call the schedule agent with the query
                        schedule_agent = ScheduleAgent(query, self.message_state)
                        agent_response = schedule_agent.process_schedule()

                        print("Schedule Agent Response: ", agent_response)

                        if agent_response["status"] == "success":
                            agent = agent_response["next_agent"]
                        elif agent_response["status"] == "error":
                            agent = "answer_agent"
                        continue

                    elif agent == "cost_agent":
                        # Call the cost agent with the query
                        cost_agent = CostAgent(query)
                        return cost_agent.process_cost()
                    
                    elif agent == "answer_agent":
                        # Call the answer agent with the query
                        answer_agent = AnswerAgent(query, agent_response)
                        answer_response = answer_agent.process_answer()

                        # print("Answer Agent Response: ", answer_response)

                        if answer_response["status"] == "success":
                            isProcessing = False
                        
                        return answer_response

        except Exception as e:
            return {"error": str(e)}

