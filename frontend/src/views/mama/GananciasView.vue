<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import api from '@/lib/api';
import { fmt } from '@/lib/format';

const data = ref<any>(null);
const cargando = ref(true);

async function cargar() {
  cargando.value = true;
  const r = await api.get('/analytics');
  data.value = r.data;
  cargando.value = false;
}
onMounted(cargar);

const meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

const barMax = computed(() => {
  if (!data.value) return 1;
  const arr: number[] = data.value.por_mes.map((m: any) => Number(m.capital) + Number(m.mora));
  return arr.length ? Math.max(...arr, 1) : 1;
});
</script>

<template>
  <div class="px-4 py-4 space-y-4">
    <div class="pt-2">
      <div class="text-2xl font-extrabold">Ganancias</div>
      <div class="text-sm text-slate-500">Análisis del negocio</div>
    </div>

    <div v-if="cargando" class="text-center py-16 text-slate-400">Cargando…</div>

    <template v-else-if="data">
      <!-- Ganancia neta -->
      <div class="card p-5 bg-gradient-to-br from-emerald-50 to-white border-emerald-200">
        <div class="text-xs text-emerald-800 font-bold uppercase tracking-wider">Ganancia neta acumulada</div>
        <div class="text-4xl font-extrabold text-emerald-700 mt-1">{{ fmt(data.totales.ganancia_neta) }}</div>
        <div class="text-xs text-slate-500 mt-1">Cobrado {{ fmt(Number(data.totales.total_cobrado_capital) + Number(data.totales.total_cobrado_mora)) }} - Prestado {{ fmt(data.totales.total_prestado_historico) }}</div>
      </div>

      <!-- Ganancia pendiente -->
      <div class="card p-4 bg-panda-50">
        <div class="text-xs text-panda-800 font-bold uppercase tracking-wider">Por ganar (si todo se cobra)</div>
        <div class="text-2xl font-extrabold text-panda-700 mt-1">{{ fmt(data.totales.ganancia_pendiente) }}</div>
      </div>

      <!-- KPIs -->
      <div class="grid grid-cols-2 gap-3">
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase">Préstamos</div>
          <div class="text-2xl font-extrabold">{{ data.totales.prestamos_totales }}</div>
          <div class="text-xs text-slate-500">{{ data.totales.prestamos_activos }} activos · {{ data.totales.prestamos_liquidados }} liquidados</div>
        </div>
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase">Clientes</div>
          <div class="text-2xl font-extrabold">{{ data.totales.clientes_totales }}</div>
          <div v-if="data.totales.en_atraso > 0" class="text-xs text-red-600 font-bold">🚨 {{ data.totales.en_atraso }} con atraso</div>
          <div v-else class="text-xs text-emerald-600">Todos al día ✓</div>
        </div>
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase">Capital cobrado</div>
          <div class="text-xl font-extrabold text-panda-700">{{ fmt(data.totales.total_cobrado_capital) }}</div>
        </div>
        <div class="card p-4">
          <div class="text-xs text-slate-500 font-bold uppercase">Mora cobrada</div>
          <div class="text-xl font-extrabold text-red-700">{{ fmt(data.totales.total_cobrado_mora) }}</div>
          <div v-if="Number(data.totales.total_mora_perdonada) > 0" class="text-xs text-amber-700">
            perdonaste {{ fmt(data.totales.total_mora_perdonada) }}
          </div>
        </div>
      </div>

      <!-- Gráfica por mes -->
      <div class="card p-4">
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider mb-3">Cobros por mes</div>
        <div v-if="data.por_mes.length === 0" class="text-center py-4 text-slate-400 text-sm">Sin datos aún</div>
        <div v-else class="space-y-2">
          <div v-for="m in data.por_mes" :key="`${m.anio}-${m.mes}`" class="flex items-center gap-2">
            <div class="w-12 text-xs text-slate-500 font-mono">{{ meses[m.mes - 1] }} {{ String(m.anio).slice(2) }}</div>
            <div class="flex-1 h-6 bg-slate-100 rounded overflow-hidden relative">
              <div class="h-full bg-gradient-to-r from-panda-400 to-panda-600"
                :style="{ width: ((Number(m.capital) + Number(m.mora)) / barMax * 100) + '%' }"></div>
              <div class="absolute inset-0 flex items-center px-2 text-xs font-bold text-slate-800">
                {{ fmt(Number(m.capital) + Number(m.mora)) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Top deuda -->
      <div v-if="data.top_deuda.length > 0" class="card p-4">
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider mb-3">Mayores deudores activos</div>
        <div class="space-y-2">
          <router-link v-for="c in data.top_deuda" :key="c.id" :to="`/mama/cliente/${c.id}`"
            class="flex items-center gap-3 py-2 border-b border-panda-100 last:border-0">
            <div class="flex-1 min-w-0">
              <div class="font-bold truncate">{{ c.nombre }}</div>
              <div class="text-xs text-slate-500">Original: {{ fmt(c.deuda_original) }}</div>
            </div>
            <div class="text-right">
              <div class="font-extrabold text-panda-700">{{ fmt(c.saldo_estimado) }}</div>
              <div class="text-xs text-slate-500">estimado</div>
            </div>
          </router-link>
        </div>
      </div>
    </template>
  </div>
</template>
