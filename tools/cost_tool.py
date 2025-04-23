COST_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "0342A_cost_variance",
            "description": """
                Earned Value Performance tool, which provides an overview of the financial performance for the project or work package. 
                This tool shows the costs and variances for projects for the current period, life-to-date, and for the entire life cycle of 
                the project. The projects can be drilled down to more accurately display the costs associated to specific PEPCC elements or 
                work packages.
            """,
            "parameters": {
                "type": "object",
                "properties": {
                    "project_number": {
                        "type": "string",
                        "description": "The project number."
                    },
                    "period": {
                        "type": "string",
                        "description": "The period for which the variance is requested."
                    }
                },
                "required": ["project_number", "period"]
            }
        }
    }
]