import os
import boto3
import time
import sys
from pathlib import Path


DATABASE = "badr_datalake"
DATABASE = os.getenv('DATABASE_NAME', 'default_db')
WORKGROUP = "primary_workgroup"
QUERIES_DIR = Path(__file__).parent.parent / "queries"

athena = boto3.client('athena')

def run_athena_query(query_sql):
    formatted_sql = query_sql.format(DATABASE=DATABASE)
    
    response = athena.start_query_execution(
        QueryString=formatted_sql,
        QueryExecutionContext={'Database': DATABASE},
        WorkGroup=WORKGROUP
    )

    execution_id = response['QueryExecutionId']
    while True:
        status = athena.get_query_execution(QueryExecutionId=execution_id)
        state = status['QueryExecution']['Status']['State']
        if state == 'SUCCEEDED': break
        elif state in ['FAILED', 'CANCELLED']:
            reason = status['QueryExecution']['Status'].get('StateChangeReason', 'Unknown')
            print(f"Error: {state} - {reason}")
            return None
        time.sleep(2)
    
    results = athena.get_query_results(QueryExecutionId=execution_id)
    return results['ResultSet']['Rows']

def print_as_table(name, rows):
    print(f"\n--- {name} ---")
    if not rows:
        print("No data found.")
        return

    # Extract headers and data
    header = [col.get('VarCharValue', 'NULL') for col in rows[0]['Data']]
    data_rows = []
    for row in rows[1:]:
        data_rows.append([col.get('VarCharValue', 'NULL') for col in row['Data']])

    # Simple ASCII formatting
    col_widths = [max(len(str(x)) for x in col) for col in zip(header, *data_rows)]
    format_str = " | ".join(["{:<" + str(w) + "}" for w in col_widths])
    
    print(format_str.format(*header))
    print("-" * (sum(col_widths) + len(col_widths) * 3))
    for r in data_rows:
        print(format_str.format(*r))


if __name__ == "__main__":
    print(f"Starting Data Validation from folder: {QUERIES_DIR}")
    
    # Iterate through all .sql files in the folder
    sql_files = list(QUERIES_DIR.glob("*.sql"))
    
    if not sql_files:
        print("No .sql files found!")
        sys.exit(0)

    for sql_file in sql_files:
        print(f"\nExecuting: {sql_file.name}")
        with open(sql_file, 'r') as f:
            query_content = f.read()
            
        try:
            results = run_athena_query(query_content)
            if results:
                print_as_table(sql_file.stem.replace('_', ' ').title(), results)
        except Exception as e:
            print(f"Failed to run {sql_file.name}: {str(e)}")
