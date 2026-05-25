from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    SECRET_KEY: str = "change-this-in-production"
    ALGORITHM: str = "HS256"
    BACKEND_INTERNAL_URL: str = "http://backend:8000"
    PUBLIC_URL: str = "https://finance.apti.dev"
    # Comma-separated allowed Origin values for browser-based requests.
    # Server-to-server clients (e.g. Claude backend) send no Origin and are always allowed.
    MCP_ALLOWED_ORIGINS: str = "https://claude.ai,https://claude.com"
    # "oauth" = only accept tokens issued by the OAuth flow (type: mcp_access).
    # "jwt"   = accept any valid signed JWT — backward-compat for pre-OAuth users.
    MCP_AUTH_MODE: str = "oauth"

    @property
    def allowed_origins(self) -> frozenset[str]:
        return frozenset(
            o.strip().rstrip("/").lower() for o in self.MCP_ALLOWED_ORIGINS.split(",") if o.strip()
        )


settings = Settings()
