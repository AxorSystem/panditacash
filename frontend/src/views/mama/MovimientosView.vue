<script setup lang="ts">
import { ref, onMounted } from 'vue';
import api from '@/lib/api';
import { fmt, fmtHora } from '@/lib/format';

const movs = ref<any[]>([]);
const stats = ref<any>(null);
const cargando = ref(true);
const filtroDesde = ref('');
const filtroHasta = ref('');

async function cargar() {
  cargando.value = true;
  const params: any = { limit: 200 };
  if (filtroDesde.value) params.desde = filtroDesde.value;
  if (filtroHasta.value) params.hasta = filtroHasta.value;
  const r = await api.get('/movimientos', { params });
  movs.value = r.data.movimientos;
  stats.value = r.data.stats;
  cargando.value = false;
}
onMounted(cargar);

const iconoMetodo: Record<string, string> = {
  efectivo: '💵', transferencia: '💳', deposito: '🏧', retencion: '🔒', otro: '💰',
};
</script>

<template>
  <div class="px-4 py-4 space-y-4">
    <div class="pt-2 flex items-center justify-between">
      <div>
        <div class="text-2xl font-extrabold">Cobros</div>
        <div class="text-sm text-slate-500">Historial cronológico</div>
      </div>
    </div>

    <!-- Filtros de fecha -->
    <div class="card p-3 grid grid-cols-2 gap-2">
      <label for="mov-desde" class="block">
        <span class="text-xs font-bold text-slate-500 uppercase">Desde</span>
        <input id="mov-desde" v-model="filtroDesde" @change="cargar" type="date" class="input py-2 text-sm" />
      </label>
      <label for="mov-hasta" class="block">
        <span class="text-xs font-bold text-slate-500 uppercase">Hasta</span>
        <input id="mov-hasta" v-model="filtroHasta" @change="cargar" type="date" class="input py-2 text-sm" />
      </label>
    </div>

    <!-- Totales del período -->
    <div v-if="stats" class="grid grid-cols-3 gap-2">
      <div class="card p-3 text-center">
        <div class="text-xs text-slate-500 font-bold uppercase">Cobros</div>
        <div class="text-lg font-extrabold">{{ stats.n_movimientos }}</div>
      </div>
      <div class="card p-3 text-center">
        <div class="text-xs text-slate-500 font-bold uppercase">Capital</div>
        <div class="text-lg font-extrabold text-panda-700">{{ fmt(stats.total_capital) }}</div>
      </div>
      <div class="card p-3 text-center">
        <div class="text-xs text-slate-500 font-bold uppercase">Mora</div>
        <div class="text-lg font-extrabold text-red-700">{{ fmt(stats.total_mora) }}</div>
      </div>
    </div>

    <div v-if="cargando" class="text-center py-16 text-slate-400">Cargando…</div>
    <div v-else-if="movs.length === 0" class="card p-8 text-center text-slate-400">
      <div class="text-4xl mb-2">📭</div>
      Sin cobros en este período
    </div>
    <div v-else class="space-y-2">
      <router-link v-for="m in movs" :key="m.id" :to="`/mama/prestamo/${m.prestamo_id}`"
        class="card p-4 flex items-center gap-3 active:scale-[0.98] transition">
        <div class="text-2xl">{{ iconoMetodo[m.metodo] || '💰' }}</div>
        <div class="flex-1 min-w-0">
          <div class="font-bold text-slate-900 truncate">{{ m.cliente_nombre }}</div>
          <div class="text-xs text-slate-500">{{ fmtHora(m.fecha_pago) }} · {{ m.metodo }}</div>
          <div v-if="m.notas" class="text-xs text-slate-600 italic truncate">"{{ m.notas }}"</div>
        </div>
        <div class="text-right">
          <div class="font-extrabold">{{ fmt(Number(m.monto_capital) + Number(m.monto_mora)) }}</div>
          <div v-if="Number(m.monto_mora) > 0" class="text-[10px] text-red-600 font-bold">+{{ fmt(m.monto_mora) }} mora</div>
          <div v-if="Number(m.mora_perdonada) > 0" class="text-[10px] text-amber-700">perdón: {{ fmt(m.mora_perdonada) }}</div>
        </div>
      </router-link>
    </div>
  </div>
</template>
