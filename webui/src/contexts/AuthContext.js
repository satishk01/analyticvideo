import React, { createContext, useContext, useState, useEffect } from 'react';

const AuthContext = createContext();

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children, authApiUrl }) => {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [sessionToken, setSessionToken] = useState(null);

  // Check for existing session on mount
  useEffect(() => {
    const token = localStorage.getItem('vus-session-token');
    if (token) {
      validateSession(token);
    } else {
      setIsLoading(false);
    }
  }, []);

  const validateSession = async (token) => {
    try {
      const response = await fetch(`${authApiUrl}/auth/validate`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      if (response.ok) {
        const data = await response.json();
        if (data.valid) {
          setUser(data.user);
          setSessionToken(token);
          localStorage.setItem('vus-session-token', token);
        } else {
          // Invalid session
          localStorage.removeItem('vus-session-token');
          setUser(null);
          setSessionToken(null);
        }
      } else {
        // Session validation failed
        localStorage.removeItem('vus-session-token');
        setUser(null);
        setSessionToken(null);
      }
    } catch (error) {
      console.error('Session validation error:', error);
      localStorage.removeItem('vus-session-token');
      setUser(null);
      setSessionToken(null);
    } finally {
      setIsLoading(false);
    }
  };

  const login = async (username, password) => {
    try {
      const response = await fetch(`${authApiUrl}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ username, password })
      });

      const data = await response.json();

      if (response.ok && data.success) {
        setUser(data.user);
        setSessionToken(data.sessionToken);
        localStorage.setItem('vus-session-token', data.sessionToken);
        return data;
      } else {
        throw new Error(data.error || 'Login failed');
      }
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      if (sessionToken) {
        await fetch(`${authApiUrl}/auth/logout`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${sessionToken}`,
            'Content-Type': 'application/json'
          }
        });
      }
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      setUser(null);
      setSessionToken(null);
      localStorage.removeItem('vus-session-token');
    }
  };

  const getAuthHeaders = () => {
    if (sessionToken) {
      return {
        'Authorization': `Bearer ${sessionToken}`,
        'Content-Type': 'application/json'
      };
    }
    return {
      'Content-Type': 'application/json'
    };
  };

  const value = {
    user,
    sessionToken,
    isLoading,
    login,
    logout,
    getAuthHeaders,
    isAuthenticated: !!user
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};