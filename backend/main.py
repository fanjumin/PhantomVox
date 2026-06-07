import os
import uuid
from datetime import datetime, timedelta
from typing import Dict, Optional

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

# ------------------------------------------------------------------
# Configuration (must be from environment variables)
# ------------------------------------------------------------------
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY environment variable not set")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme (tokenUrl for documentation)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

# ------------------------------------------------------------------
# In-memory "database" (for demonstration only)
# ------------------------------------------------------------------
# user_db: username -> {"hashed_password", "email", "is_active"}
user_db = {}

# refresh_token_db: refresh_token_id -> {"username", "expires_at", "revoked"}
refresh_token_db: Dict[str, dict] = {}

# ------------------------------------------------------------------
# Models
# ------------------------------------------------------------------
class User(BaseModel):
    username: str
    email: Optional[str] = None
    is_active: bool = True

class UserInDB(User):
    hashed_password: str

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class LoginResponse(Token):
    pass

class RegisterRequest(BaseModel):
    username: str
    password: str
    email: Optional[str] = None

# ------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------
def get_user(username: str) -> Optional[UserInDB]:
    user = user_db.get(username)
    if user:
        return UserInDB(**user)
    return None

def create_access_token(data: dict, expires_delta: timedelta = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    to_encode["type"] = "access"  # Mark token type
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(username: str) -> str:
    """Create a new refresh token, store it, and return the token string."""
    token_id = str(uuid.uuid4())
    expires = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_token_db[token_id] = {
        "username": username,
        "expires_at": expires,
        "revoked": False
    }
    payload = {
        "sub": username,
        "type": "refresh",
        "jti": token_id,
        "exp": expires
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str, expected_type: str) -> dict:
    """Verify JWT token and check its type. Returns payload if valid."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        token_type = payload.get("type")
        if token_type != expected_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token type. Expected '{expected_type}', got '{token_type}'",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Dependency that returns the current user from an access token."""
    payload = verify_token(token, "access")
    username = payload.get("sub")
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = get_user(username)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    return user

# ------------------------------------------------------------------
# FastAPI app
# ------------------------------------------------------------------
app = FastAPI(title="JWT Login with Refresh Token Rotation")

# ------------------------------------------------------------------
# Endpoints
# ------------------------------------------------------------------
@app.post("/register", status_code=status.HTTP_201_CREATED)
def register(request: RegisterRequest):
    """Register a new user."""
    if get_user(request.username):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username already registered")
    hashed_password = pwd_context.hash(request.password)
    user_dict = {
        "username": request.username,
        "hashed_password": hashed_password,
        "email": request.email,
        "is_active": True
    }
    user_db[request.username] = user_dict
    return {"msg": "User created successfully"}

@app.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """Authenticate user and return tokens."""
    user = get_user(form_data.username)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    if not pwd_context.verify(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Inactive user")
    access_token = create_access_token(data={"sub": user.username})
    refresh_token = create_refresh_token(username=user.username)
    return Token(access_token=access_token, refresh_token=refresh_token)

@app.post("/refresh", response_model=Token)
def refresh_token(request: RefreshTokenRequest):
    """Exchange a valid refresh token for a new access token and a new refresh token (rotation)."""
    # Verify the refresh token
    try:
        payload = jwt.decode(request.refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    token_type = payload.get("type")
    if token_type != "refresh":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token is not a refresh token")
    token_id = payload.get("jti")
    if not token_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token (missing jti)")
    # Check if token is stored and not revoked
    stored = refresh_token_db.get(token_id)
    if stored is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token not found")
    if stored["revoked"]:
        # Additional security: if a revoked token is reused, revoke all tokens for the user
        username = stored["username"]
        for tid, data in list(refresh_token_db.items()):
            if data["username"] == username and not data["revoked"]:
                data["revoked"] = True
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token revoked")
    if stored["expires_at"] < datetime.utcnow():
        # Remove expired token and raise
        del refresh_token_db[token_id]
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token expired")
    # Revoke old refresh token (rotation)
    stored["revoked"] = True
    # Generate new tokens
    username = stored["username"]
    access_token = create_access_token(data={"sub": username})
    new_refresh_token = create_refresh_token(username=username)
    return Token(access_token=access_token, refresh_token=new_refresh_token)

@app.get("/users/me", response_model=User)
def read_users_me(current_user: UserInDB = Depends(get_current_user)):
    """Return the current user's information. Protected endpoint."""
    return current_user