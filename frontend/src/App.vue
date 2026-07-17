<script setup lang="ts">
import { computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();

const showNav = computed(() => auth.isAuth && route.name !== 'login');

function logout() {
  auth.logout();
  router.push('/login');
}
</script>

<template>
  <div class="min-h-screen flex flex-col max-w-md mx-auto bg-panda-50">
    <nav v-if="showNav" class="sticky top-0 z-10 bg-white/95 backdrop-blur border-b border-panda-100 px-4 py-3 flex items-center justify-between shadow-sm">
      <router-link :to="auth.esMama ? '/mama' : '/mi-prestamo'" class="flex items-center gap-2">
        <img src="/logo.svg" alt="PanditaCash" class="w-9 h-9" />
        <div>
          <div class="font-bold text-lg leading-none bg-gradient-to-r from-panda-500 to-panda-700 bg-clip-text text-transparent">PanditaCash</div>
          <div class="text-[10px] text-slate-500 uppercase tracking-wider">{{ auth.esMama ? 'Panel Mamá' : 'Mis préstamos' }}</div>
        </div>
      </router-link>
      <button @click="logout" class="text-slate-400 hover:text-slate-700 text-sm">Salir</button>
    </nav>
    <router-view class="flex-1" />
  </div>
</template>
