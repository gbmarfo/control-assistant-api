INTENT_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "send_query_to_agents",
            "description": "Send the user's question to the appropriate agent based on the identified intent.",
            "parameters": {
                "type": "object",
                "properties": {
                    "agents": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "An array of agent names to send the query to."
                    },
                    "query": {
                        "type": "string",
                        "description": "The user's question."
                    }
                },
                "required": ["required", "query"]
            }
        }
    }
]