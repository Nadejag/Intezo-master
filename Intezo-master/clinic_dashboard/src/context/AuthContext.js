import { createContext, useContext, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { loginClinic, getClinicProfile } from '../api/clinicApi';

const AuthContext = createContext();

export const useAuth = () => useContext(AuthContext);


export const AuthProvider = ({ children }) => {
  const [currentUser, setCurrentUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const initializeAuth = async () => {
      const userData = localStorage.getItem('clinicUser');
      if (userData) {
        try {
          const user = JSON.parse(userData);
          await getClinicProfile();
          setCurrentUser(user);
        } catch (error) {
          localStorage.removeItem('clinicUser');
        }
      }
      setLoading(false);
    };
    initializeAuth();
  }, []);

  const login = async (email, password) => {
    try {
      const response = await loginClinic(email, password);
      const user = {
        token: response.data.token,
        clinic: response.data.clinic
      };
      localStorage.setItem('clinicUser', JSON.stringify(user));
      setCurrentUser(user);
      return response;
    } catch (error) {
      throw error;
    }
  };

  const logout = () => {
    localStorage.removeItem('clinicUser');
    setCurrentUser(null);
    navigate('/login');
  };

  const value = {
    currentUser,
    login,
    logout,
    loading
  };

  return (
    <AuthContext.Provider value={value}>
      {!loading && children}
    </AuthContext.Provider>
  );
};

export default AuthProvider;