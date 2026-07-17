<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import api from '@/lib/api';

const props = defineProps<{ id: string }>();
const router = useRouter();

const data = ref<any>(null);
const cargando = ref(true);
const pagoSel = ref<any>(null);
const montoPagado = ref<number>(0);
const moraPerdonada = ref<number>(0);
const notas = ref('');
const guardando = ref(false);

async function cargar() {
  cargando.value = true;
  const r = await api.get(`/prestamos/${props.id}`);
  data.value = r.data;
  cargando.value = false;
}
onMounted(cargar);

function abrirPago(pg: any) {
  pagoSel.value = pg;
  montoPagado.value = Number(pg.total_a_cobrar_hoy);
  moraPerdonada.value = 0;
  notas.value = '';
}

async function registrarPago() {
  guardando.value = true;
  try {
    await api.post(`/prestamos/${props.id}/pagar`, {
      pago_id: pagoSel.value.id,
      monto_pagado: montoPagado.value,
      mora_perdonada: moraPerdonada.value,
      notas: notas.value,
    });
    pagoSel.value = null;
    await cargar();
  } finally { guardando.value = false; }
}

const progreso = computed(() => {
  if (!data.value) return 0;
  const done = data.value.pagos.filter((p: any) => p.estado === 'pagado' || p.estado === 'pagado_anticipado').length;
  return Math.round((done / data.value.pagos.length) * 100);
});

function fmt(n: number) { return '$' + Math.round(n).toLocaleString('es-MX'); }
function fmtDia(d: string) { return new Date(d).toLocaleDateString('es-MX', { day: '2-digit', month: 'short', year: 'numeric' }); }
const estadoColor: Record<string, string> = {
  pagado: 'text-emerald-700', pagado_anticipado: 'text-emerald-700',
  pendiente: 'text-amber-700', vencido: 'text-red-700',
};
const estadoIcon: Record<string, string> = {
  pagado: '✅', pagado_anticipado: '💰', pendiente: '⏳', vencido: '🚨',
};
</script>

<template>
  <div v-if="cargando" class="text-center py-20 text-slate-400">Cargando...</div>
  <div v-else-if="data" class="px-4 py-4 pb-16 space-y-4">
    <div class="flex items-center gap-3">
      <button @click="router.back()" class="text-panda-700 text-lg">←</button>
      <div class="flex-1 min-w-0">
        <h1 class="text-2xl font-extrabold truncate">{{ data.cliente_nombre }}</h1>
        <div class="text-sm text-slate-500">📱 {{ data.cliente_tel }}</div>
      </div>
    </div>

    <!-- Resumen del préstamo -->
    <div class="card p-5 space-y-2 bg-gradient-to-br from-panda-50 to-white border-panda-200">
      <div class="text-xs font-bold text-panda-700 uppercase tracking-wider">Préstamo</div>
      <div class="text-4xl font-extrabold">{{ fmt(data.principal) }}</div>
      <div class="flex items-center gap-2 text-sm text-slate-600">
        <span>📅 {{ data.plazo_meses }} meses</span>
        <span>·</span>
        <span>{{ (data.tasa_mensual * 100).toFixed(0) }}% / mes</span>
        <span v-if="data.mora_diaria > 0">·</span>
        <span v-if="data.mora_diaria > 0">🚨 {{ fmt(data.mora_diaria) }}/día</span>
      </div>
      <div class="h-2 bg-panda-100 rounded-full overflow-hidden mt-2">
        <div class="h-full bg-gradient-to-r from-panda-500 to-panda-700 rounded-full" :style="{ width: progreso + '%' }"></div>
      </div>
      <div class="flex justify-between text-xs text-slate-500 mt-1">
        <span>Pagado {{ fmt(data.total_pagado) }}</span>
        <span>Falta {{ fmt(data.total_pendiente) }}</span>
      </div>
    </div>

    <!-- Próximo pago -->
    <div v-if="data.proximo" class="card p-5 border-panda-300"
      :class="data.proximo.dias_retraso > 0 ? 'bg-red-50 border-red-300' : 'bg-white'">
      <div class="text-xs font-bold uppercase tracking-wider" :class="data.proximo.dias_retraso > 0 ? 'text-red-700' : 'text-panda-700'">
        {{ data.proximo.dias_retraso > 0 ? 'Vencido' : 'Próximo pago' }}
      </div>
      <div class="text-3xl font-extrabold mt-1">{{ fmt(data.proximo.total_a_cobrar_hoy) }}</div>
      <div class="text-sm text-slate-600 mt-1">Programado: {{ fmtDia(data.proximo.fecha_programada) }}</div>
      <div v-if="data.proximo.mora_acumulada_hoy > 0" class="text-sm text-red-600 mt-1">
        Incluye {{ fmt(data.proximo.mora_acumulada_hoy) }} mora ({{ data.proximo.dias_retraso }} días)
      </div>
      <button @click="abrirPago(data.proximo)" class="btn-primary w-full mt-4">💰 Registrar pago</button>
    </div>

    <!-- Historial de pagos -->
    <div class="space-y-2">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1 pt-2">Historial</div>
      <div v-for="p in data.pagos" :key="p.id" class="card p-4 flex items-center gap-3">
        <div class="text-2xl">{{ estadoIcon[p.estado] || '⏳' }}</div>
        <div class="flex-1 min-w-0">
          <div class="font-bold">Pago {{ p.numero_pago }} de {{ data.plazo_meses }}</div>
          <div class="text-xs text-slate-500">{{ fmtDia(p.fecha_programada) }}</div>
          <div v-if="p.notas" class="text-xs text-slate-600 mt-1 italic truncate">{{ p.notas.split('\n')[0] }}</div>
        </div>
        <div class="text-right">
          <div class="font-extrabold" :class="estadoColor[p.estado] || 'text-slate-700'">
            {{ fmt(p.monto_pagado || p.monto_esperado) }}
          </div>
          <div class="text-xs uppercase font-bold" :class="estadoColor[p.estado]">
            {{ p.estado === 'pagado_anticipado' ? 'ANTICIPADO' : p.estado.toUpperCase() }}
          </div>
        </div>
      </div>
    </div>

    <!-- Modal registrar pago -->
    <div v-if="pagoSel" class="fixed inset-0 bg-black/50 z-30 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="bg-white rounded-t-3xl sm:rounded-3xl w-full max-w-md p-6 space-y-4">
        <div class="flex justify-between items-center">
          <h3 class="text-xl font-extrabold">Registrar pago</h3>
          <button @click="pagoSel = null" class="text-slate-400 text-2xl">×</button>
        </div>
        <div class="text-sm text-slate-600 space-y-1">
          <div>Debía pagar: <b>{{ fmt(pagoSel.monto_esperado) }}</b></div>
          <div v-if="pagoSel.mora_acumulada_hoy > 0" class="text-red-600">Mora acumulada: <b>{{ fmt(pagoSel.mora_acumulada_hoy) }}</b> ({{ pagoSel.dias_retraso }} días)</div>
          <div class="font-bold pt-1">Total esperado: {{ fmt(pagoSel.total_a_cobrar_hoy) }}</div>
        </div>
        <label for="mp-monto" class="block">
          <span class="text-sm font-semibold text-slate-600">¿Cuánto pagó?</span>
          <input id="mp-monto" v-model.number="montoPagado" type="number" class="input mt-1 text-2xl font-bold" />
        </label>
        <label v-if="pagoSel.mora_acumulada_hoy > 0" for="mp-mora" class="block">
          <span class="text-sm font-semibold text-slate-600">Perdonar mora (opcional)</span>
          <input id="mp-mora" v-model.number="moraPerdonada" type="number" class="input mt-1" :max="pagoSel.mora_acumulada_hoy" />
          <span class="text-xs text-slate-400">Máximo: {{ fmt(pagoSel.mora_acumulada_hoy) }}</span>
        </label>
        <label for="mp-notas" class="block">
          <span class="text-sm font-semibold text-slate-600">Notas (opcional)</span>
          <input id="mp-notas" v-model="notas" placeholder="Ej: pagó en efectivo" class="input mt-1" />
        </label>
        <button @click="registrarPago" :disabled="guardando" class="btn-primary w-full text-lg py-4">
          {{ guardando ? 'Guardando...' : '✓ Confirmar pago' }}
        </button>
      </div>
    </div>
  </div>
</template>
