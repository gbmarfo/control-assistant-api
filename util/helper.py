import re
import ast
import json
from markitdown import MarkItDown

class Helper:
    """
    Helper class for various
    utility functions.
    """

    @staticmethod
    def extract_json_from_string(text: str) -> str:
        """
        Extract JSON from a string using regex.
        """
        pattern = r'```json\s(.*?)```'
        matches = re.findall(pattern, text, re.DOTALL)
        if not matches:
            return None
        else:
            return matches[0]
        
    @staticmethod
    def json_parser(input_string: str) -> dict:
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
            return {"Json parser error": str(e)}
        
    
    @staticmethod
    def convert_to_markdown(data_path: str) -> str:
        """
        Convert the given data to markdown format.
        """
        try:
            # create MarkItDown instance
            md = MarkItDown(enable_plugins=False)

            # Use MarkItDown to convert the data to markdown format
            markdown_data = md.convert(data_path)

            return markdown_data.text_content
        
        except Exception as e:
            return str(e)