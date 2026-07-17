<script setup lang="ts">
import { computed } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();

const showNav = computed(() => auth.isAuth && route.name !== 'login');
const isCliente = computed(() => auth.isAuth && !auth.esMama);
const isMama = computed(() => auth.esMama);

function logout() {
  auth.logout();
  router.push('/login');
}

const tabs = [
  { path: '/mama', name: 'mama-dashboard', icon: '🏠', label: 'Inicio' },
  { path: '/mama/clientes', name: 'mama-clientes', icon: '👥', label: 'Clientes' },
  { path: '/mama/movimientos', name: 'mama-movimientos', icon: '💵', label: 'Cobros' },
  { path: '/mama/ganancias', name: 'mama-ganancias', icon: '📊', label: 'Ganancias' },
];
</script>

<template>
  <div class="min-h-screen flex flex-col max-w-md mx-auto bg-panda-50 relative">
    <nav v-if="showNav" class="sticky top-0 z-10 bg-white/95 backdrop-blur border-b border-panda-100 px-4 py-3 flex items-center justify-between shadow-sm">
      <router-link :to="isMama ? '/mama' : '/mi-prestamo'" class="flex items-center gap-2">
        <img src="/logo.svg" alt="PanditaCash" class="w-9 h-9" />
        <div>
          <div class="font-bold text-lg leading-none bg-gradient-to-r from-panda-500 to-panda-700 bg-clip-text text-transparent">PanditaCash</div>
          <div class="text-[10px] text-slate-500 uppercase tracking-wider truncate max-w-[180px]">{{ auth.user?.nombre }}</div>
        </div>
      </router-link>
      <button @click="logout" class="text-slate-400 hover:text-slate-700 text-sm">Salir</button>
    </nav>

    <router-view :class="[showNav && isMama ? 'pb-24' : '', 'flex-1']" />

    <!-- Bottom nav solo para mamá -->
    <nav v-if="showNav && isMama" class="fixed bottom-0 inset-x-0 max-w-md mx-auto bg-white border-t border-panda-100 shadow-lg z-20">
      <div class="grid grid-cols-4">
        <router-link v-for="t in tabs" :key="t.path" :to="t.path"
          class="flex flex-col items-center py-2 gap-0.5 transition"
          :class="route.name === t.name ? 'text-panda-700' : 'text-slate-500'">
          <div class="text-2xl">{{ t.icon }}</div>
          <div class="text-[10px] font-bold uppercase tracking-wider">{{ t.label }}</div>
        </router-link>
      </div>
    </nav>
  </div>
</template>
