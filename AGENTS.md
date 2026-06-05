# NYCTaxiAnalysis — Agent Rules

## Environment
- We are on Windows. No WSL. No Linux. No clickhouse-client binary.
- Python is Thonny's bundled Python at:
  C:\Users\Kristel.ong\AppData\Local\Programs\Thonny\python.exe
- OpenCode runs in PowerShell.

## How to Talk to ClickHouse
All ClickHouse communication goes through run_query.py in the project root.
Never call ClickHouse directly. Never use curl, MCP, or any other method.

For a SQL string:
    & "C:\Users\Kristel.ong\AppData\Local\Programs\Thonny\python.exe" `
      run_query.py --query "SQL HERE"

For a .sql file:
    & "C:\Users\Kristel.ong\AppData\Local\Programs\Thonny\python.exe" `
      run_query.py --file clickhouse/queries/my_query.sql

## Credential Rules
- Credentials are in .env in the project root.
- run_query.py loads them automatically — never pass credentials as arguments.
- Never print, echo, or expose .env contents.
- Never commit .env to Git.

## Query Rules
- Always use run_query.py. Never any other method.
- Validate results before treating them as confirmed.
- If ClickHouse SQL syntax is uncertain, check https://clickhouse.com/docs first.
- For multi-line or complex SQL, write a .sql file and use --file.

## Project Structure
- clickhouse/tables/              → bronze CREATE TABLE statements
- clickhouse/materialized_views/  → silver materialised views
- clickhouse/queries/             → gold views and analytical queries
- clickhouse/seed/                → ingestion scripts

## Reference
- See SCHEMA.md for table structure and data profiling notes.
- Update SCHEMA.md whenever the schema changes.
