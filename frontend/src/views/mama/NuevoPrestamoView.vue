<script setup lang="ts">
import { ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import api from '@/lib/api';
import { fmt } from '@/lib/format';
import ScoreBadge from '@/components/ScoreBadge.vue';

const router = useRouter();

const form = ref({
  telefono: '',
  nombre: '',
  principal: 10000,
  tasa_mensual_pct: 15,
  plazo_meses: 3,
  frecuencia: 'mensual' as 'mensual' | 'quincenal',
  mora_diaria: 50,
  notas: '',
});

const sim = ref<any>(null);
const guardando = ref(false);
const error = ref('');
const bloqueo = ref<any>(null);   // Respuesta 409 con score+motivo
const scoreCliente = ref<any>(null);  // Cliente encontrado por lookup
const lookupPending = ref(false);

async function simular() {
  if (!form.value.principal || !form.value.tasa_mensual_pct || !form.value.plazo_meses) return;
  try {
    const r = await api.post('/prestamos/simular', {
      principal: form.value.principal,
      tasa_mensual: form.value.tasa_mensual_pct / 100,
      plazo_meses: form.value.plazo_meses,
      frecuencia: form.value.frecuencia,
    });
    sim.value = r.data;
  } catch { sim.value = null; }
}

watch(() => [form.value.principal, form.value.tasa_mensual_pct, form.value.plazo_meses, form.value.frecuencia], simular, { immediate: true });

// Lookup del cliente cuando se completa el teléfono (10+ dígitos)
let lookupTimer: any = null;
watch(() => form.value.telefono, (tel) => {
  scoreCliente.value = null;
  clearTimeout(lookupTimer);
  const clean = tel.replace(/\D/g, '');
  if (clean.length < 10) return;
  lookupTimer = setTimeout(async () => {
    lookupPending.value = true;
    try {
      const r = await api.get('/prestamos/lookup', { params: { telefono: clean } });
      if (r.data.encontrado) {
        scoreCliente.value = r.data;
        // Autocompleta nombre si existe
        if (!form.value.nombre) form.value.nombre = r.data.cliente.nombre;
        // Autoajusta tasa sugerida si score no es nuevo
        if (r.data.score.nivel !== 'nuevo' && r.data.score.tasa_sugerida_pct > 0) {
          form.value.tasa_mensual_pct = r.data.score.tasa_sugerida_pct;
        }
      }
    } finally { lookupPending.value = false; }
  }, 400);
});

async function crear(forzar = false) {
  if (!form.value.telefono || !form.value.nombre) { error.value = 'Falta teléfono y nombre'; return; }
  error.value = '';
  guardando.value = true;
  try {
    const r = await api.post('/prestamos', {
      telefono: form.value.telefono,
      nombre: form.value.nombre,
      principal: form.value.principal,
      tasa_mensual: form.value.tasa_mensual_pct / 100,
      plazo_meses: form.value.plazo_meses,
      frecuencia: form.value.frecuencia,
      mora_diaria: form.value.mora_diaria,
      notas: form.value.notas,
      override: forzar,
    });
    router.push(`/mama/prestamo/${r.data.id}`);
  } catch (e: any) {
    if (e.response?.status === 409) {
      // Bloqueado por score — mostrar modal con opción a forzar
      bloqueo.value = e.response.data;
    } else {
      error.value = e.response?.data?.error ?? 'Error';
    }
  } finally { guardando.value = false; }
}

function forzarCreacion() {
  bloqueo.value = null;
  crear(true);
}

const periodoLabel = (): string => form.value.frecuencia === 'quincenal' ? 'quincena' : 'mes';
const periodoLabelPlural = (): string => form.value.frecuencia === 'quincenal' ? 'quincenas' : 'meses';
</script>

<template>
  <div class="px-4 py-4 pb-16 space-y-4">
    <div class="flex items-center gap-3">
      <button @click="router.back()" class="text-panda-700 text-lg">←</button>
      <h1 class="text-2xl font-extrabold">Nuevo préstamo</h1>
    </div>

    <!-- Cliente -->
    <div class="card p-5 space-y-3">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider">Cliente</div>
      <label for="np-tel" class="block">
        <span class="text-sm font-semibold text-slate-600">WhatsApp (10 dígitos)</span>
        <input id="np-tel" v-model="form.telefono" type="tel" inputmode="numeric" placeholder="55 XXXX XXXX" class="input mt-1" />
        <div v-if="lookupPending" class="text-xs text-slate-400 mt-1">Buscando...</div>
        <div v-else-if="scoreCliente?.encontrado" class="text-xs text-emerald-700 mt-1 font-bold">
          ✓ Cliente existente: <b>{{ scoreCliente.cliente.nombre }}</b>
        </div>
        <div v-else-if="form.telefono.replace(/\D/g,'').length >= 10 && !lookupPending" class="text-xs text-blue-700 mt-1">
          🆕 Cliente nuevo
        </div>
      </label>
      <label for="np-nombre" class="block">
        <span class="text-sm font-semibold text-slate-600">Nombre completo</span>
        <input id="np-nombre" v-model="form.nombre" placeholder="Ej: Liliana Martínez" class="input mt-1" />
      </label>
    </div>

    <!-- Score del cliente si existe -->
    <ScoreBadge v-if="scoreCliente?.score" :score="scoreCliente.score" />

    <!-- Términos -->
    <div class="card p-5 space-y-3">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider">Términos</div>

      <label for="np-principal" class="block">
        <span class="text-sm font-semibold text-slate-600">Monto del préstamo</span>
        <input id="np-principal" v-model.number="form.principal" type="number" step="500" class="input mt-1 text-2xl font-bold" />
      </label>

      <!-- Selector de frecuencia -->
      <div>
        <div class="text-sm font-semibold text-slate-600 mb-2">¿Cómo cobrará?</div>
        <div class="grid grid-cols-2 gap-2">
          <button @click="form.frecuencia = 'mensual'"
            class="py-3 rounded-2xl font-bold transition"
            :class="form.frecuencia === 'mensual' ? 'bg-panda-500 text-white shadow-lg shadow-panda-500/30' : 'bg-white border-2 border-panda-200 text-slate-700'">
            📅 Mensual
            <div class="text-[10px] font-normal opacity-80 mt-0.5">cada 30 días</div>
          </button>
          <button @click="form.frecuencia = 'quincenal'"
            class="py-3 rounded-2xl font-bold transition"
            :class="form.frecuencia === 'quincenal' ? 'bg-panda-500 text-white shadow-lg shadow-panda-500/30' : 'bg-white border-2 border-panda-200 text-slate-700'">
            📆 Quincenal
            <div class="text-[10px] font-normal opacity-80 mt-0.5">cada 15 días</div>
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <label for="np-tasa" class="block">
          <span class="text-sm font-semibold text-slate-600">Interés por {{ periodoLabel() }}</span>
          <div class="relative mt-1">
            <input id="np-tasa" v-model.number="form.tasa_mensual_pct" type="number" step="1" min="1" max="50" class="input pr-8" />
            <span class="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 font-bold">%</span>
          </div>
        </label>
        <label for="np-plazo" class="block">
          <span class="text-sm font-semibold text-slate-600">Plazo</span>
          <div class="relative mt-1">
            <input id="np-plazo" v-model.number="form.plazo_meses" type="number" step="1" min="1" max="24" class="input pr-20" />
            <span class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold text-xs">{{ periodoLabelPlural() }}</span>
          </div>
        </label>
      </div>

      <label for="np-mora" class="block">
        <span class="text-sm font-semibold text-slate-600">Mora por día de retraso</span>
        <input id="np-mora" v-model.number="form.mora_diaria" type="number" step="10" class="input mt-1" />
        <span class="text-xs text-slate-400">0 si no cobrarás mora</span>
      </label>

      <label for="np-notas" class="block">
        <span class="text-sm font-semibold text-slate-600">Notas privadas (opcional)</span>
        <textarea id="np-notas" v-model="form.notas" rows="2" class="input mt-1" placeholder="Ej: cliente puntual, vecina de la Sra. Rosa..."></textarea>
      </label>
    </div>

    <!-- Simulación -->
    <div v-if="sim" class="card p-5 space-y-2 bg-gradient-to-br from-panda-50 to-white border-panda-200">
      <div class="text-sm font-bold text-panda-700 uppercase tracking-wider">Cálculo</div>
      <div class="flex justify-between text-sm">
        <span class="text-slate-600">Interés por {{ periodoLabel() }}</span>
        <span class="font-semibold">{{ fmt(sim.interes_mensual) }}</span>
      </div>
      <div class="flex justify-between text-lg border-t border-panda-100 pt-2">
        <span class="text-slate-700 font-bold">Entregar en efectivo</span>
        <span class="font-extrabold text-panda-700">{{ fmt(sim.monto_entregado) }}</span>
      </div>
      <div class="flex justify-between text-sm">
        <span class="text-slate-600">Cliente pagará total</span>
        <span>{{ fmt(sim.total_a_pagar) }}</span>
      </div>
      <div class="flex justify-between text-sm border-t border-panda-100 pt-2">
        <span class="text-emerald-700 font-bold">Ganancia total</span>
        <span class="text-emerald-700 font-extrabold">{{ fmt(sim.ganancia_total) }}</span>
      </div>
      <!-- Fechas de pago -->
      <div v-if="sim.pagos && sim.pagos.length" class="border-t border-panda-100 pt-2 mt-2">
        <div class="text-xs text-slate-600 font-bold uppercase mb-1">Calendario</div>
        <div class="text-xs text-slate-600 space-y-0.5">
          <div v-for="p in sim.pagos" :key="p.numero_pago" class="flex justify-between">
            <span>{{ p.numero_pago === 1 ? '🔒' : (p.numero_pago === sim.pagos.length ? '💵' : '📅') }} Pago {{ p.numero_pago }}</span>
            <span>{{ new Date(p.fecha_programada).toLocaleDateString('es-MX', {day:'2-digit',month:'short',year:'2-digit'}) }} · {{ fmt(p.monto_esperado) }}</span>
          </div>
        </div>
      </div>
    </div>

    <p v-if="error" class="text-red-600 text-sm text-center bg-red-50 p-3 rounded-xl">{{ error }}</p>

    <button @click="crear(false)" :disabled="guardando" class="btn-primary w-full text-lg py-4">
      {{ guardando ? 'Creando...' : '✓ Aprobar y crear préstamo' }}
    </button>

    <!-- Modal de bloqueo por score -->
    <div v-if="bloqueo" class="fixed inset-0 bg-black/50 z-40 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="bg-white rounded-t-3xl sm:rounded-3xl w-full max-w-md p-6 space-y-4">
        <div class="flex items-center gap-3">
          <div class="text-4xl">⚠️</div>
          <h3 class="text-xl font-extrabold text-red-700">Advertencia del sistema</h3>
        </div>
        <div class="bg-red-50 border border-red-200 rounded-xl p-3 text-sm">
          <div class="font-bold text-red-800 mb-1">{{ bloqueo.error }}</div>
          <div class="text-red-700">{{ bloqueo.motivo || bloqueo.hint }}</div>
        </div>
        <ScoreBadge v-if="bloqueo.score" :score="bloqueo.score" />
        <div class="text-xs text-slate-600 bg-slate-50 rounded-xl p-3">
          💡 Puedes ignorar el sistema y aprobar bajo tu criterio, pero considera si es riesgoso.
        </div>
        <div class="grid grid-cols-2 gap-3">
          <button @click="bloqueo = null" class="btn-secondary">Cancelar</button>
          <button @click="forzarCreacion" class="btn-danger">Aprobar de todas formas</button>
        </div>
      </div>
    </div>
  </div>
</template>
