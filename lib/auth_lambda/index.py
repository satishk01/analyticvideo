import json
import boto3
import hashlib
import secrets
import time
from datetime import datetime, timedelta
import os

# Hardcoded credentials for demo purposes
ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "admin"
SESSION_TIMEOUT_MINUTES = 480  # 8 hours

# In-memory session store (for demo - in production use DynamoDB)
sessions = {}

def lambda_handler(event, context):
    """
    Authentication Lambda handler
    Supports login, logout, and session validation
    """
    try:
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        if http_method == 'POST' and path.endswith('/login'):
            return handle_login(event)
        elif http_method == 'POST' and path.endswith('/logout'):
            return handle_logout(event)
        elif http_method == 'GET' and path.endswith('/validate'):
            return handle_validate(event)
        else:
            return create_response(404, {'error': 'Not found'})
            
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {'error': 'Internal server error'})

def handle_login(event):
    """Handle user login"""
    try:
        body = json.loads(event.get('body', '{}'))
        username = body.get('username', '')
        password = body.get('password', '')
        
        # Validate credentials
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            # Create session
            session_token = generate_session_token()
            session_data = {
                'userId': username,
                'createdAt': int(time.time()),
                'expiresAt': int(time.time()) + (SESSION_TIMEOUT_MINUTES * 60),
                'isActive': True
            }
            
            # Store session (in production, use DynamoDB)
            sessions[session_token] = session_data
            
            return create_response(200, {
                'success': True,
                'sessionToken': session_token,
                'expiresAt': session_data['expiresAt'],
                'user': {'username': username}
            })
        else:
            return create_response(401, {'error': 'Invalid credentials'})
            
    except Exception as e:
        print(f"Error in handle_login: {str(e)}")
        return create_response(500, {'error': 'Login failed'})

def handle_logout(event):
    """Handle user logout"""
    try:
        session_token = extract_session_token(event)
        
        if session_token and session_token in sessions:
            # Invalidate session
            sessions[session_token]['isActive'] = False
            del sessions[session_token]
            
        return create_response(200, {'success': True, 'message': 'Logged out successfully'})
        
    except Exception as e:
        print(f"Error in handle_logout: {str(e)}")
        return create_response(500, {'error': 'Logout failed'})

def handle_validate(event):
    """Validate session token"""
    try:
        session_token = extract_session_token(event)
        
        if not session_token:
            return create_response(401, {'error': 'No session token provided'})
            
        session_data = sessions.get(session_token)
        
        if not session_data:
            return create_response(401, {'error': 'Invalid session'})
            
        # Check if session is expired
        if session_data['expiresAt'] < int(time.time()):
            # Clean up expired session
            del sessions[session_token]
            return create_response(401, {'error': 'Session expired'})
            
        if not session_data['isActive']:
            return create_response(401, {'error': 'Session inactive'})
            
        return create_response(200, {
            'valid': True,
            'user': {'username': session_data['userId']},
            'expiresAt': session_data['expiresAt']
        })
        
    except Exception as e:
        print(f"Error in handle_validate: {str(e)}")
        return create_response(500, {'error': 'Validation failed'})

def generate_session_token():
    """Generate a secure session token"""
    return secrets.token_urlsafe(32)

def extract_session_token(event):
    """Extract session token from request headers or query parameters"""
    # Try Authorization header first
    headers = event.get('headers', {})
    auth_header = headers.get('Authorization', '') or headers.get('authorization', '')
    
    if auth_header.startswith('Bearer '):
        return auth_header[7:]
    
    # Try query parameters
    query_params = event.get('queryStringParameters') or {}
    return query_params.get('token')

def create_response(status_code, body):
    """Create HTTP response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
        },
        'body': json.dumps(body)
    }