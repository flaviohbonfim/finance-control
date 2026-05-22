from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    SECRET_KEY: str = "change-this-in-production"
    ALGORITHM: str = "HS256"
    BACKEND_INTERNAL_URL: str = "http://backend:8000"


settings = Settings()
