import os
from fastapi import FastAPI, Depends, HTTPException, Header, WebSocket, Request
from fastapi.responses import HTMLResponse
import requests
import logging

# Set up logging for production
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            # Send request to Open Web UI model endpoint
            headers = {
                "Authorization": f"Bearer {API_TOKEN}",
            }
            data = {
                "model": MODEL_NAME,
                "prompt": data,
            }
            try:
                # Make the POST request to Open Web UI's model endpoint
                response = requests.post(f"{OPEN_WEB_UI_URL}/api/chat", headers=headers, json=data)
                response.raise_for_status()  # Raise an exception for HTTP error responses
                result = response.json()
                response_text = result.get("choices")[0]["text"]
            except requests.exceptions.RequestException as e:
                logger.error(f"Error with LLM provider: {str(e)}")
                response_text = "Error with the LLM provider"
            
            await websocket.send_text(response_text)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await websocket.close()

# Get environment variables for Aider LLM provider and Open Web UI
API_TOKEN = os.getenv("API_TOKEN")
OPEN_WEB_UI_URL = os.getenv("OPEN_WEB_UI_URL")
MODEL_NAME = os.getenv("MODEL_NAME", "gpt-3.5-turbo")

# Health check endpoint for Coolify
@app.get("/health")
def health_check():
    """Health check endpoint for Coolify"""
    return {"status": "ok"}

# Verify the API token from the request headers
def verify_token(authorization: str = Header(None)):
    if authorization != f"Bearer {API_TOKEN}":
        logger.warning("Invalid API token attempt")
        raise HTTPException(status_code=401, detail="Invalid token")
    return True

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    with open("index.html") as f:
        html_content = f.read()
    return HTMLResponse(content=html_content, status_code=200)

@app.get("/secure-endpoint")
def secure_data(authenticated: bool = Depends(verify_token)):
    return {"message": "You have access to secure data!"}

@app.get("/query")
def query_llm(prompt: str, authenticated: bool = Depends(verify_token)):
    if not OPEN_WEB_UI_URL:
        logger.error("OPEN_WEB_UI_URL environment variable is missing")
        raise HTTPException(status_code=500, detail="Open Web UI URL not configured")

    # Send request to Open Web UI model endpoint
    headers = {
        "Authorization": f"Bearer {API_TOKEN}",
    }
    data = {
        "model": MODEL_NAME,
        "prompt": prompt,
    }
    try:
        # Make the POST request to Open Web UI's model endpoint
        response = requests.post(f"{OPEN_WEB_UI_URL}/v1/completions", headers=headers, json=data)
        response.raise_for_status()  # Raise an exception for HTTP error responses
        result = response.json()
        return {"response": result.get("choices")[0]["text"]}
    except requests.exceptions.RequestException as e:
        logger.error(f"Error with LLM provider: {str(e)}")
        raise HTTPException(status_code=500, detail="Error with the LLM provider")

# Catch-all error handler for unexpected exceptions
@app.exception_handler(Exception)
async def generic_exception_handler(request, exc):
    logger.error(f"Unexpected error: {exc}")
    return {"detail": "Internal server error"}
