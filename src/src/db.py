import os
import asyncpg
import logging
from azure.identity import DefaultAzureCredential
from opentelemetry import trace
from opentelemetry.trace import StatusCode

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)

DB_HOST = os.getenv("PGHOST")
DB_PORT = os.getenv("PGPORT")
DB_NAME = os.getenv("PGDATABASE", "postgres")
DB_USER = os.getenv("PGUSER")
credential = DefaultAzureCredential(exclude_managed_identity_credential=(os.getenv("EXCLUDE_MANAGED_IDENTITY") == "true"))

async def get_db_connection(database: str = DB_NAME):
    """Get a database connection"""
    try:
        # Consider caching the token and getting a new one only if it's expired
        DB_PASSWORD = credential.get_token("https://ossrdbms-aad.database.windows.net/.default").token
        conn = await asyncpg.connect(user=DB_USER, password=DB_PASSWORD, host=DB_HOST, 
                                     port=DB_PORT, database=database, ssl='require')
        return conn
    except Exception as e:
        logger.error(f"Database connection error: {e}")
        raise


async def create_managed_identity_user(identity: str):
    conn = None
    with tracer.start_as_current_span("db_query") as span:
        try:
            conn = await get_db_connection("postgres")
            # Using parameterized query instead of string interpolation
            # This is safer against SQL injection attacks
            result = await conn.fetch("select * from pgaadauth_create_principal($1, false, false);", identity)
            span.set_status(StatusCode.OK)
            return result
        except Exception as e:
            logger.error(f"Query execution error: {e}")
            span.set_status(StatusCode.ERROR)
            raise
        finally:
            if conn:
                await conn.close() 

async def execute_query(query):
    """Execute a SQL query and return results if fetch is True"""
    conn = None
    with tracer.start_as_current_span("db_query") as span:
        try:
            span.set_attribute("db_query.statement", query)
            conn = await get_db_connection("demodatabase")
            result = await conn.fetch(query)
            span.set_status(StatusCode.OK)
            return result
        except Exception as e:
            logger.error(f"Query execution error: {e}")
            span.set_status(StatusCode.ERROR)
            raise
        finally:
            if conn:
                await conn.close() 