from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    SECRET_KEY: str = "change-this-in-production"
    ALGORITHM: str = "HS256"
    BACKEND_INTERNAL_URL: str = "http://backend:8000"
    PUBLIC_URL: str = "https://finance.apti.dev"
    MCP_ALLOWED_ORIGINS: str = "https://claude.ai,https://claude.com,https://finance.apti.dev,http://localhost:5173"

    @property
    def allowed_origins(self) -> frozenset[str]:
        return frozenset(
            o.strip().rstrip("/").lower()
            for o in self.MCP_ALLOWED_ORIGINS.split(",")
            if o.strip()
        )


settings = Settings()
