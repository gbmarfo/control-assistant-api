from typing import AsyncGenerator, cast
from openai import RateLimitError

async def stream_with_errors(generator: AsyncGenerator[str, None]) -> AsyncGenerator[str, None]:
    """
    Stream the generator and handle RateLimitError by retrying the request.
    """
    try:
        async for chunk in generator:
            yield chunk
    except RateLimitError as e:
        body = cast(dict, e.body)
        error_msg = body.get("message", "OpenaAI API rate limit exceeded.")
        yield f"Error: {error_msg}"
    except Exception as e:
        yield f"Error: {str(e)}"  # Yield error message and exit loop