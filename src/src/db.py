import os
import asyncpg
import logging
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI
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

async def create_vector():
    conn = await get_db_connection()
    await conn.execute("""
        CREATE EXTENSION vector;
    """)
    await conn.close()
    return {"status": "success", "message": "Vector extension created"}

async def create_and_fill_vector_table():
    conn = await get_db_connection()
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS faculties (
            id SERIAL PRIMARY KEY,
            text TEXT NOT NULL,
            embedding vector(3072) NOT NULL
        );
    """)

    # Insert sample data
    client = AzureOpenAI(
        azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT"), 
        azure_ad_token_provider = get_bearer_token_provider(
            credential, "https://cognitiveservices.azure.com/.default"
        ),
        api_version="2025-03-01-preview"
    )

    faculties = [
        "Arcane Studies and Mystical Theory",
        "Department of Enchanted Botany",
        "School of Chronomantic Arts",
        "Faculty of Elemental Manipulation",
        "Institute of Ancient Runes and Lost Languages",
        "Department of Alchemical Innovations",
        "School of Magical Beasts and Familiar Studies",
        "Faculty of Astral Navigation and Celestial Lore",
        "Department of Hexes, Jinxes, and Defensive Sorcery",
        "Institute of Mirror Magic and Dimensional Portals"
    ]

    response = client.embeddings.create(
        model = "text-embedding-3-large",
        input = faculties
    )

    # Insert embeddings into the vector_table
    await conn.execute("DELETE FROM faculties")
    for i, embedding_data in enumerate(response.data):
        text = faculties[i]
        embedding = embedding_data.embedding

        # Convert embedding array to a comma-separated string for debugging
        embedding_str = '[' + ','.join(str(value) for value in embedding) + ']'
        
        # Insert the text and its embedding into the table
        # PostgreSQL pgvector extension can accept array directly
        await conn.execute(
            "INSERT INTO faculties (text, embedding) VALUES ($1, $2)",
            text, embedding_str
        )
    
    await conn.close()
    return {"status": "success", "message": "Vector table created and filled with embeddings"}

async def vector_search(query: str):
    client = AzureOpenAI(
        azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT"), 
        azure_ad_token_provider = get_bearer_token_provider(
            credential, "https://cognitiveservices.azure.com/.default"
        ),
        api_version="2025-03-01-preview"
    )

    response = client.embeddings.create(
        model = "text-embedding-3-large",
        input = query
    )

    embedding_str = '[' + ','.join(str(value) for value in response.data[0].embedding) + ']'

    conn = await get_db_connection()
    result = await conn.fetch(
        "SELECT text, embedding <=> $1 AS similarity FROM faculties ORDER BY embedding <=> $1 LIMIT 3",
        embedding_str
    )
    await conn.close()
    return result