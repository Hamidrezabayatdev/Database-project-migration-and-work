from pydantic import BaseModel, EmailStr, Field
from typing import Optional


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, description="At least 6 characters")
    first_name: str = Field(min_length=1)
    last_name: str = Field(min_length=1)
    nationality_country_id: Optional[int] = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class ApplyRequest(BaseModel):
    cover_letter: Optional[str] = Field(default=None, max_length=2000)
