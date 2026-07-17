import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '@/lib/api';

interface User {
  id: number;
  nombre: string;
  es_admin: boolean;
}

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(localStorage.getItem('pandita_token'));
  const user = ref<User | null>(JSON.parse(localStorage.getItem('pandita_user') || 'null'));

  const isAuth = computed(() => !!token.value);
  const esMama = computed(() => !!user.value?.es_admin);

  function setSession(t: string, u: User) {
    token.value = t;
    user.value = u;
    localStorage.setItem('pandita_token', t);
    localStorage.setItem('pandita_user', JSON.stringify(u));
  }

  async function loginMama(telefono: string, pin: string) {
    const r = await api.post('/auth/mama/login', { telefono, pin });
    setSession(r.data.token, r.data.user);
  }

  async function requestOtp(telefono: string, nombre?: string) {
    const r = await api.post('/auth/cliente/request-otp', { telefono, nombre });
    return r.data;
  }

  async function verifyOtp(telefono: string, codigo: string) {
    const r = await api.post('/auth/cliente/verify-otp', { telefono, codigo });
    setSession(r.data.token, r.data.user);
  }

  function logout() {
    token.value = null;
    user.value = null;
    localStorage.removeItem('pandita_token');
    localStorage.removeItem('pandita_user');
  }

  return { token, user, isAuth, esMama, setSession, loginMama, requestOtp, verifyOtp, logout };
});
