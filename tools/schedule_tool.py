SCHEDULE_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "0225A_level_2_project_performance",
            "description": "Provides the schedule performance for each program by bundle. Identifies the amount of hours allocated to each project, both planned and earned value.",
            "parameters": {
                "type": "object",
                "properties": {
                    "period": {
                        "type": "string",
                        "description": "The period for which the performance is requested."
                    },
                    "project_number": {
                        "type": "string",
                        "description": "The project number."
                    },
                    "period_type": {
                        "type": "string",
                        "description": "The type of period (e.g., Weekly, Monthly)."
                    }
                    
                },
                "required": ["period", "project_number", "period_type"]
            }
        },
        "strict": True
    },
    {
        "type": "function",
        "function": {
            "name": "0220X_schedule_variance_summary",
            "description": "Summarizes schedule variance / start/finish dates for various DNRU4 activities.",
            "parameters": {
                "type": "object",
                "properties": {
                    "project": {
                        "type": "string",
                        "description": "The project number."
                    },
                    "period": {
                        "type": "string",
                        "description": """The period for which the variance is requested. 
                                            Should be in the format YYYY-MM-DD. 
                                            Important to specify the period by the user. 
                                            Request for user to specify if not present in question.
                                            Example: 2024-08-01
                                        """
                    },
                    "piepccc": {
                        "type": "string",
                        "description": """The PIEC project code. Important to specify the PIEC project code by the user. 
                                            Request for user to specify if not present in question with the following guidelines:
                                            - 0 for Cost Management
                                            - 1 for Project Management
                                            - 2 for Inspection
                                            - 3 for Engineering
                                            - 4 for Procurement
                                            - 5 for Construction
                                            - 6 for Commissioning
                                            - 9 for Close-Out
                                            """
                    }
                },
                "required": ["project", "period", "piepccc"]
            }
        },
        "strict": True
    }
]
