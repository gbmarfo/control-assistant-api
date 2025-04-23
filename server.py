import os
from typing import AsyncGenerator, NoReturn
from openai import AsyncOpenAI
from fastapi import FastAPI, Body, WebSocket, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from utils.utils import stream_with_errors
from pydantic import BaseModel
from agents.intent_agent import IntentAgent

# Load environment variables from .env file
load_dotenv()


# Initialize FastAPI app and OpenAI client
app = FastAPI(
    title="Control Assistant API",
    description="API for chat interactions with Project Controls.",
    version="1.0.0",
    docs_url="/docs"
)

# Middleware for CORS
# This allows cross-origin requests from any origin.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# instance of OpenAI client
client = AsyncOpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
)

class ChatMessage(BaseModel):
    '''
    Request model for chat messages.
    '''
    user: str
    system: str = "You are a helpful assistant."


async def get_ai_response(message: str) -> AsyncGenerator[str, None]:
    '''
    OpenAI Response 
    Asynchronous generator to stream response chunks
    '''
    response = await client.chat.completions.create(
        model=os.getenv("LLM_MODEL"),
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a helpful assistant."
                )
            },
            {
                "role": "user",
                "content": message
            }
        ],
        stream=True
    )

    all_content = ""

    async for chunk in response:
        content = chunk.choices[0].delta.content
        if content:
            all_content += content
            yield all_content


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> NoReturn:
    '''
    Websocket fo AI responses
    Stream from LLM responses to UI
    '''
    await websocket.accept()

    while True:
        message = await websocket.receive_text()
        async for text in get_ai_response(message):
            await websocket.send_text(text)

@app.post("/ask")
async def ask(message: ChatMessage):
    '''
    Chat endpoint.
    '''
    try:
        response = await client.chat.completions.create(
            model=os.getenv("LLM_MODEL"),
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a helpful assistant."
                    )
                },
                {
                    "role": "user",
                    "content": message.user
                }
            ]
        )

        return {
            'response': response.choices[0].message.content
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    

@app.get("/agent")
async def agent(question: str):
    """
    Endpoint to process the question and get the agent's response.
    """
    try:
        intent_agent = IntentAgent(question=question)
        response = intent_agent.process_intent()

        if response["status"] == "success":
            return {
                "question": question,
                "status": response["status"],
                "message": response["message"],
                "response": response["response"]
            }
        else:
            raise HTTPException(status_code=400, detail=response["message"])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    
@app.get("/healthcheck")
def healthcheck():
    """
    Health check endpoint to verify if the server is running.
    """
    return {"status": "ok"}

@app.get("/")
def root():
    """
    Root endpoint to verify if the server is running.
    """
    return {"message": "Welcome to the Control Assistant API!"}