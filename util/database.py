import os
import pyodbc
import pandas as pd
from pathlib import Path
from dotenv import load_dotenv

# load environment variable
load_dotenv()

class SqlQueryExecutor:
    def __init__(self):
        self.connection_string = (
            f"DRIVER={os.getenv('DB_DRIVER')};"
            f"SERVER={os.getenv('DB_HOST')};"
            f"DATABASE={os.getenv('DB_NAME')};"
            f"Trusted_Connection={os.getenv('DB_TRUSTED_CONNECTION')};"
        )

    def execute_query_from_file(self, sql_file_path: Path, params: tuple):
        """
        Execute the SQL query from the specified file with the given parameters.
        """
        try:
            # Read the SQL query from the file
            with open(sql_file_path, 'r') as file:
                sql_query = file.read()

            with pyodbc.connect(self.connection_string) as conn:
                if params:
                    df = pd.read_sql_query(sql_query, conn, params=params)
                else:
                    df = pd.read_sql_query(sql_query, conn)

                return df
            
        except FileNotFoundError:
            raise FileNotFoundError(f"SQL file {sql_file_path} not found.")
        except pyodbc.Error as e:
            raise Exception(f"Database error: {str(e)}")

