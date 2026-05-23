from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from jose import JWTError, jwt

from app.core.config import settings
from app.tools.definitions import TOOLS
from app.tools.executor import execute_tool

app = FastAPI(title="Finance Control MCP", docs_url=None, redoc_url=None)

_PROTOCOL_VERSION = "2024-11-05"


def _validate_token(authorization: str | None) -> int | None:
    if not authorization or not authorization.startswith("Bearer "):
        return None
    try:
        payload = jwt.decode(
            authorization[7:], settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        return int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        return None


def _unauthorized():
    resource_metadata = f"{settings.PUBLIC_URL}/.well-known/oauth-protected-resource"
    return JSONResponse(
        status_code=401,
        content={"error": "unauthorized"},
        headers={"WWW-Authenticate": f'Bearer resource_metadata="{resource_metadata}"'},
    )


def _rpc_error(id_, code: int, message: str) -> dict:
    return {"jsonrpc": "2.0", "id": id_, "error": {"code": code, "message": message}}


def _rpc_ok(id_, result: dict) -> dict:
    return {"jsonrpc": "2.0", "id": id_, "result": result}


async def _handle_message(msg: dict, user_id: int, token: str) -> dict | None:
    id_ = msg.get("id")
    method = msg.get("method", "")
    params = msg.get("params") or {}

    # Notifications have no id and need no response
    if id_ is None:
        return None

    if method == "initialize":
        return _rpc_ok(
            id_,
            {
                "protocolVersion": _PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "Finance Control MCP", "version": "1.0.0"},
            },
        )

    if method == "tools/list":
        return _rpc_ok(id_, {"tools": TOOLS})

    if method == "tools/call":
        tool_name = params.get("name", "")
        arguments = params.get("arguments") or {}
        try:
            result_text = await execute_tool(tool_name, arguments, token)
            return _rpc_ok(
                id_,
                {"content": [{"type": "text", "text": result_text}], "isError": False},
            )
        except Exception as exc:
            return _rpc_ok(
                id_,
                {"content": [{"type": "text", "text": f"Erro: {exc}"}], "isError": True},
            )

    if method == "ping":
        return _rpc_ok(id_, {})

    return _rpc_error(id_, -32601, f"Method not found: {method}")


@app.get("/")
async def mcp_discover():
    return _unauthorized()


@app.post("/")
async def mcp_handler(request: Request):
    user_id = _validate_token(request.headers.get("Authorization"))
    if user_id is None:
        return _unauthorized()

    token = request.headers["Authorization"][7:]

    try:
        body = await request.json()
    except Exception:
        return JSONResponse(_rpc_error(None, -32700, "Parse error"), status_code=400)

    if isinstance(body, list):
        responses = []
        for msg in body:
            resp = await _handle_message(msg, user_id, token)
            if resp is not None:
                responses.append(resp)
        return JSONResponse(responses)

    resp = await _handle_message(body, user_id, token)
    if resp is None:
        return JSONResponse({}, status_code=204)
    return JSONResponse(resp)


@app.get("/health")
async def health():
    return {"status": "ok"}
