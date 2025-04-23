AGENT_PROMPT = """

Context: 
{context}

Available tools:
- {tool_descriptions}

Based on the user's input and context, decide if you should use a tool or respond to the user directly.
If you decide to use a tool, respond with the tool name and the arguments for the tool.
If you decide to respond directly to the user then makee the action "respond_to_user" with args as your response in the following format.

Response Format:
{response_format}

"""