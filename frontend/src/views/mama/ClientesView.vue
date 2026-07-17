<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import api from '@/lib/api';
import { fmt } from '@/lib/format';

interface Cliente {
  id: number; nombre: string; telefono: string; notas: string | null;
  n_prestamos: number; activos: number;
  deuda_original: number; total_pagado_capital: number;
  saldo_real: number; vencidos: number;
  atrasos_historicos: number;
}

const clientes = ref<Cliente[]>([]);
const cargando = ref(true);
const buscar = ref('');
const filtro = ref<'todos' | 'activos' | 'atrasados'>('todos');

async function cargar() {
  cargando.value = true;
  try {
    const r = await api.get('/clientes', { params: { buscar: buscar.value } });
    clientes.value = r.data;
  } finally { cargando.value = false; }
}
onMounted(cargar);

let timer: any = null;
function buscarConDebounce() {
  clearTimeout(timer);
  timer = setTimeout(cargar, 300);
}

const filtrados = computed(() => {
  if (filtro.value === 'activos') return clientes.value.filter(c => c.activos > 0);
  if (filtro.value === 'atrasados') return clientes.value.filter(c => c.vencidos > 0);
  return clientes.value;
});
</script>

<template>
  <div class="px-4 py-4 space-y-4">
    <div class="pt-2">
      <div class="text-2xl font-extrabold">Clientes</div>
      <div class="text-sm text-slate-500">{{ clientes.length }} en total</div>
    </div>

    <!-- Buscador -->
    <label for="buscar-cli" class="block">
      <input id="buscar-cli" v-model="buscar" @input="buscarConDebounce" type="search"
        placeholder="🔎 Buscar por nombre o teléfono" class="input" />
    </label>

    <!-- Filtro -->
    <div class="flex gap-2">
      <button @click="filtro = 'todos'"
        class="flex-1 py-2 rounded-full font-bold text-sm transition"
        :class="filtro === 'todos' ? 'bg-panda-500 text-white' : 'bg-white border border-panda-200 text-slate-600'">
        Todos
      </button>
      <button @click="filtro = 'activos'"
        class="flex-1 py-2 rounded-full font-bold text-sm transition"
        :class="filtro === 'activos' ? 'bg-panda-500 text-white' : 'bg-white border border-panda-200 text-slate-600'">
        Con préstamo
      </button>
      <button @click="filtro = 'atrasados'"
        class="flex-1 py-2 rounded-full font-bold text-sm transition"
        :class="filtro === 'atrasados' ? 'bg-red-500 text-white' : 'bg-white border border-panda-200 text-slate-600'">
        Atrasados
      </button>
    </div>

    <div v-if="cargando" class="text-center py-16 text-slate-400">Cargando…</div>
    <div v-else-if="filtrados.length === 0" class="card p-8 text-center text-slate-400">
      <div class="text-4xl mb-2">👥</div>
      Sin clientes que coincidan
    </div>
    <div v-else class="space-y-2">
      <router-link v-for="c in filtrados" :key="c.id" :to="`/mama/cliente/${c.id}`"
        class="card p-4 flex items-center gap-3 active:scale-[0.98] transition"
        :class="{ 'border-red-300 bg-red-50': c.vencidos > 0 }">
        <div class="w-12 h-12 rounded-full bg-gradient-to-br from-panda-400 to-panda-600 flex items-center justify-center text-white font-bold text-lg shrink-0">
          {{ c.nombre.split(' ').map(x => x[0]).slice(0, 2).join('').toUpperCase() }}
        </div>
        <div class="flex-1 min-w-0">
          <div class="font-bold text-slate-900 truncate">{{ c.nombre }}</div>
          <div class="flex items-center gap-2 mt-0.5 flex-wrap">
            <span v-if="c.activos > 0" class="text-xs text-panda-700 font-bold">
              📄 {{ c.activos }} activo{{ c.activos === 1 ? '' : 's' }}
            </span>
            <span v-else class="text-xs text-slate-400">📄 {{ c.n_prestamos }} histórico{{ c.n_prestamos === 1 ? '' : 's' }}</span>
            <span v-if="c.vencidos > 0" class="chip-danger">🚨 {{ c.vencidos }} vencido{{ c.vencidos === 1 ? '' : 's' }}</span>
            <span v-else-if="c.atrasos_historicos > 0" class="text-xs text-amber-700">⏰ {{ c.atrasos_historicos }} atraso{{ c.atrasos_historicos === 1 ? '' : 's' }} antes</span>
            <span v-else-if="c.n_prestamos > 0" class="text-xs text-emerald-700">✓ Puntual</span>
          </div>
        </div>
        <div v-if="c.saldo_real > 0" class="text-right">
          <div class="font-extrabold" :class="c.vencidos > 0 ? 'text-red-700' : 'text-slate-800'">{{ fmt(c.saldo_real) }}</div>
          <div class="text-xs text-slate-500">debe</div>
        </div>
      </router-link>
    </div>
  </div>
</template>
