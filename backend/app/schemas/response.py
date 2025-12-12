from typing import Generic, TypeVar, Optional, Any
from pydantic import BaseModel

T = TypeVar('T')

class ApiResponse(BaseModel, Generic[T]):
    status: str = "success"
    data: Optional[T] = None
    message: Optional[str] = None

class ApiError(BaseModel):
    status: str = "error"
    code: int
    message: str
    errors: Optional[Any] = None
