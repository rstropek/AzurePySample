import os

from typing import Union
import asyncio

from fastapi import FastAPI, HTTPException
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

from dotenv import load_dotenv
load_dotenv()

import logging
from opentelemetry import trace
from azure.monitor.opentelemetry import configure_azure_monitor
configure_azure_monitor()
logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
token_provider = get_bearer_token_provider(
    DefaultAzureCredential(exclude_managed_identity_credential=(os.getenv("EXCLUDE_MANAGED_IDENTITY") == "true")), "https://cognitiveservices.azure.com/.default"
)

# Import database module
from db import create_managed_identity_user, execute_query

from openai import AzureOpenAI

app = FastAPI()

@app.get("/")
async def read_root():
    logger.warning("Hello World")
    with tracer.start_as_current_span("root_request"):
        await asyncio.sleep(1)
        logger.warning("In span")
    return {"Hello": "World"}

@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    return {"item_id": item_id, "q": q}

@app.get("/db/test")
async def test_db_connection():
    """Test the database connection"""
    try:
        # Simple test query that works on any PostgreSQL database
        result = await execute_query("SELECT current_timestamp as time, current_database() as database")
        return {"status": "success", "data": result}
    except Exception as e:
        logger.error(f"Database error: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.get("/db/create")
async def create_managed_identity_user_handler(identity: str = "testuser"):
    try:
        result = await create_managed_identity_user(identity)
        return {"status": "success", "data": result}
    except Exception as e:
        logger.error(f"Database error: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

@app.get("/openai")
async def openai_test():
    try:
        client = AzureOpenAI(
            azure_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT"), 
            azure_ad_token_provider=token_provider,
            api_version="2025-03-01-preview"
        )

        response = client.responses.create(
            model=os.getenv("MODEL_NAME"), 
            input="Are dolphin fish?",
            max_output_tokens=4096 # Note that this currently is required for new responses API (preview)
        )

        return {"status": "success", "data": response.output_text}
    except Exception as e:
        logger.error(f"OpenAI error: {e}")
        return str(e)

FastAPIInstrumentor.instrument_app(app)
