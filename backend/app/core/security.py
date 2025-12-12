import bcrypt

# Password hashing config (using pure bcrypt to avoid passlib+bcrypt 5.0 issues)

def verify_password(plain_password, hashed_password):
    # bcrypt requires bytes
    if isinstance(hashed_password, str):
        hashed_password = hashed_password.encode('utf-8')
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password)

def get_password_hash(password):
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')
