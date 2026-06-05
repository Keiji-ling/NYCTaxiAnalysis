import clickhouse_connect
import os
import sys
import argparse
from dotenv import load_dotenv

load_dotenv()

def get_client():
    return clickhouse_connect.get_client(
    	host=os.getenv('CLICKHOUSE_HOST'),
    	port=int(os.getenv('CLICKHOUSE_PORT', 8443)),
    	username=os.getenv('CLICKHOUSE_USER'),
    	password=os.getenv('CLICKHOUSE_PASSWORD'),
    	secure=True,
    	verify=False
)
def main():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--query', help='SQL string to execute')
    group.add_argument('--file', help='Path to .sql file to execute')
    args = parser.parse_args()

    if args.file:
        with open(args.file, 'r') as f:
            sql = f.read()
    else:
        sql = args.query

    try:
        client = get_client()
        result = client.command(sql)
        if result is not None:
            print(result)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
