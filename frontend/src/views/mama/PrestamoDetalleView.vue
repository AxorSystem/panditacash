<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import api from '@/lib/api';
import { fmt, fmtDia, fmtHora } from '@/lib/format';

const props = defineProps<{ id: string }>();
const router = useRouter();

const data = ref<any>(null);
const cargando = ref(true);
const pagoSel = ref<any>(null);
const monto = ref<number>(0);
const moraPerdonada = ref<number>(0);
const metodo = ref('efectivo');
const notas = ref('');
const guardando = ref(false);

async function cargar() {
  cargando.value = true;
  const r = await api.get(`/prestamos/${props.id}`);
  data.value = r.data;
  cargando.value = false;
}
onMounted(cargar);

function abrirCobro(pg: any) {
  pagoSel.value = pg;
  monto.value = Number(pg.total_pendiente);
  moraPerdonada.value = 0;
  metodo.value = 'efectivo';
  notas.value = '';
}

async function registrarCobro() {
  guardando.value = true;
  try {
    await api.post(`/prestamos/${props.id}/cobrar`, {
      pago_id: pagoSel.value.id,
      monto: monto.value,
      mora_perdonada: moraPerdonada.value,
      metodo: metodo.value,
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

const estadoIcon: Record<string, string> = {
  pagado: '✅', pagado_anticipado: '🔒', pendiente: '⏳', parcial: '🟡',
};
const estadoLabel: Record<string, string> = {
  pagado: 'Pagado', pagado_anticipado: 'Anticipado', pendiente: 'Pendiente', parcial: 'Parcial',
};
const estadoColor: Record<string, string> = {
  pagado: 'text-emerald-700', pagado_anticipado: 'text-emerald-700',
  pendiente: 'text-amber-700', parcial: 'text-orange-700',
};
</script>

<template>
  <div v-if="cargando" class="text-center py-20 text-slate-400">Cargando...</div>
  <div v-else-if="data" class="px-4 py-4 space-y-4">
    <div class="flex items-center gap-3">
      <button @click="router.back()" class="text-panda-700 text-lg">←</button>
      <router-link :to="`/mama/cliente/${data.uid}`" class="flex-1 min-w-0">
        <div class="text-xl font-extrabold truncate">{{ data.cliente_nombre }}</div>
        <div class="text-xs text-slate-500 flex items-center gap-1">💬 {{ data.cliente_tel }}</div>
      </router-link>
      <span class="chip" :class="data.estado === 'activo' ? 'bg-panda-100 text-panda-800' : 'bg-emerald-100 text-emerald-700'">
        {{ data.estado }}
      </span>
    </div>

    <!-- Resumen -->
    <div class="card p-5 space-y-2 bg-gradient-to-br from-panda-50 to-white border-panda-200">
      <div class="text-xs font-bold text-panda-700 uppercase tracking-wider">Préstamo</div>
      <div class="text-4xl font-extrabold">{{ fmt(data.principal) }}</div>
      <div class="flex items-center gap-2 text-sm text-slate-600 flex-wrap">
        <span>📅 {{ data.plazo_meses }} meses</span>
        <span>·</span>
        <span>{{ (data.tasa_mensual * 100).toFixed(0) }}% / mes</span>
        <span v-if="Number(data.mora_diaria) > 0">·</span>
        <span v-if="Number(data.mora_diaria) > 0">🚨 {{ fmt(data.mora_diaria) }}/día mora</span>
      </div>
      <div class="text-xs text-slate-500">Inicio: {{ fmtDia(data.fecha_inicio) }}</div>
      <div class="h-2 bg-panda-100 rounded-full overflow-hidden mt-2">
        <div class="h-full bg-gradient-to-r from-panda-500 to-panda-700 rounded-full transition-all" :style="{ width: progreso + '%' }"></div>
      </div>
      <div class="flex justify-between text-xs text-slate-500 mt-1">
        <span>Cobrado {{ fmt(Number(data.total_pagado_capital) + Number(data.total_pagado_mora)) }}</span>
        <span>Falta {{ fmt(data.total_pendiente) }}</span>
      </div>
    </div>

    <!-- Próximo pago con botón cobrar -->
    <div v-if="data.proximo" class="card p-5"
      :class="data.proximo.dias_retraso > 0 ? 'bg-red-50 border-red-300' : 'bg-white border-panda-300'">
      <div class="text-xs font-bold uppercase tracking-wider" :class="data.proximo.dias_retraso > 0 ? 'text-red-700' : 'text-panda-700'">
        {{ data.proximo.dias_retraso > 0 ? '🚨 Debe pagarte' : 'Próximo pago' }}
      </div>
      <div class="text-3xl font-extrabold mt-1">{{ fmt(data.proximo.total_pendiente) }}</div>
      <div class="text-sm text-slate-600 mt-1">
        Programado: {{ fmtDia(data.proximo.fecha_programada) }}
      </div>
      <div v-if="Number(data.proximo.monto_pagado_capital) > 0 || Number(data.proximo.monto_pagado_mora) > 0" class="text-sm text-orange-700 mt-1 font-bold">
        Ya cobraste {{ fmt(Number(data.proximo.monto_pagado_capital) + Number(data.proximo.monto_pagado_mora)) }} de este pago
      </div>
      <div v-if="Number(data.proximo.mora_pendiente) > 0" class="text-sm text-red-600 mt-1">
        Incluye {{ fmt(data.proximo.mora_pendiente) }} de mora ({{ data.proximo.dias_retraso }} días)
      </div>
      <button @click="abrirCobro(data.proximo)" class="btn-primary w-full mt-4 text-lg py-4">
        💵 Cobrar
      </button>
    </div>

    <!-- Historial de pagos programados -->
    <div class="space-y-2">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1">Pagos del préstamo</div>
      <div v-for="p in data.pagos" :key="p.id" class="card p-3 flex items-center gap-3">
        <div class="text-2xl">{{ estadoIcon[p.estado] || '⏳' }}</div>
        <div class="flex-1 min-w-0">
          <div class="font-bold">Pago {{ p.numero_pago }} de {{ data.plazo_meses }}</div>
          <div class="text-xs text-slate-500">{{ fmtDia(p.fecha_programada) }}</div>
          <div v-if="p.estado === 'parcial'" class="text-xs text-orange-700 font-bold">
            Falta {{ fmt(p.total_pendiente) }}
          </div>
        </div>
        <div class="text-right">
          <div class="font-extrabold" :class="estadoColor[p.estado]">
            {{ fmt(p.monto_esperado) }}
          </div>
          <div class="text-[10px] uppercase font-bold" :class="estadoColor[p.estado]">
            {{ estadoLabel[p.estado] }}
          </div>
        </div>
      </div>
    </div>

    <!-- Historial de cobros de este préstamo -->
    <div v-if="data.movimientos.length > 0" class="space-y-2">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1">Cobros ({{ data.movimientos.length }})</div>
      <div v-for="m in data.movimientos" :key="m.id" class="card p-3 flex items-center gap-3">
        <div class="text-xl">💵</div>
        <div class="flex-1 min-w-0">
          <div class="font-bold">{{ fmt(Number(m.monto_capital) + Number(m.monto_mora)) }}</div>
          <div class="text-xs text-slate-500">
            {{ fmtHora(m.fecha_pago) }} · {{ m.metodo }}
            <span v-if="Number(m.monto_mora) > 0"> · {{ fmt(m.monto_mora) }} mora</span>
          </div>
          <div v-if="m.notas" class="text-xs text-slate-600 italic truncate">"{{ m.notas }}"</div>
        </div>
      </div>
    </div>

    <!-- Modal cobrar -->
    <div v-if="pagoSel" class="fixed inset-0 bg-black/50 z-40 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="bg-white rounded-t-3xl sm:rounded-3xl w-full max-w-md p-6 space-y-4 max-h-[95vh] overflow-y-auto">
        <div class="flex justify-between items-center">
          <h3 class="text-xl font-extrabold">Registrar cobro</h3>
          <button @click="pagoSel = null" class="text-slate-400 text-2xl">×</button>
        </div>
        <div class="text-sm text-slate-600 space-y-1 bg-panda-50 rounded-xl p-3">
          <div>Debe: <b>{{ fmt(pagoSel.capital_pendiente) }}</b> capital</div>
          <div v-if="Number(pagoSel.mora_pendiente) > 0" class="text-red-600">
            + <b>{{ fmt(pagoSel.mora_pendiente) }}</b> mora ({{ pagoSel.dias_retraso }} días)
          </div>
          <div class="font-extrabold pt-1 text-panda-700">Total esperado: {{ fmt(pagoSel.total_pendiente) }}</div>
        </div>
        <label for="cob-monto" class="block">
          <span class="text-sm font-semibold text-slate-600">¿Cuánto recibiste?</span>
          <input id="cob-monto" v-model.number="monto" type="number" class="input mt-1 text-2xl font-bold text-center" />
          <p class="text-xs text-slate-500 mt-1">Puedes cobrar menos si es un pago parcial.</p>
        </label>
        <label v-if="Number(pagoSel.mora_pendiente) > 0" for="cob-mora" class="block">
          <span class="text-sm font-semibold text-slate-600">¿Perdonar parte de la mora?</span>
          <input id="cob-mora" v-model.number="moraPerdonada" type="number" class="input mt-1" :max="pagoSel.mora_pendiente" />
          <p class="text-xs text-slate-500 mt-1">Máx: {{ fmt(pagoSel.mora_pendiente) }}</p>
        </label>
        <label for="cob-metodo" class="block">
          <span class="text-sm font-semibold text-slate-600">Método</span>
          <select id="cob-metodo" v-model="metodo" class="input mt-1">
            <option value="efectivo">💵 Efectivo</option>
            <option value="transferencia">💳 Transferencia</option>
            <option value="deposito">🏧 Depósito</option>
            <option value="otro">💰 Otro</option>
          </select>
        </label>
        <label for="cob-notas" class="block">
          <span class="text-sm font-semibold text-slate-600">Notas (opcional)</span>
          <input id="cob-notas" v-model="notas" placeholder="Ej: pagó por Oxxo con recibo" class="input mt-1" />
        </label>
        <button @click="registrarCobro" :disabled="guardando" class="btn-primary w-full text-lg py-4">
          {{ guardando ? 'Guardando...' : '✓ Confirmar cobro' }}
        </button>
      </div>
    </div>
  </div>
</template>
