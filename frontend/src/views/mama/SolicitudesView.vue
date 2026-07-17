<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import api from '@/lib/api';

const router = useRouter();
const items = ref<any[]>([]);
const cargando = ref(true);
const seleccionada = ref<any>(null);
const tasa = ref(15);
const mora = ref(50);
const respNotas = ref('');
const guardando = ref(false);

async function cargar() {
  cargando.value = true;
  const r = await api.get('/prestamos/dashboard');
  items.value = r.data.solicitudes_pendientes;
  cargando.value = false;
}
onMounted(cargar);

async function responder(accion: 'aprobar' | 'rechazar') {
  guardando.value = true;
  try {
    const r = await api.post(`/solicitudes/${seleccionada.value.id}/responder`, {
      accion,
      tasa_mensual: accion === 'aprobar' ? tasa.value / 100 : undefined,
      mora_diaria: accion === 'aprobar' ? mora.value : undefined,
      notas: respNotas.value,
    });
    seleccionada.value = null;
    if (accion === 'aprobar' && r.data.prestamo_id) {
      router.push(`/mama/prestamo/${r.data.prestamo_id}`);
    } else {
      await cargar();
    }
  } finally { guardando.value = false; }
}

function fmt(n: number) { return '$' + Math.round(n).toLocaleString('es-MX'); }
function fmtDia(d: string) { return new Date(d).toLocaleDateString('es-MX', { day: '2-digit', month: 'short' }); }
</script>

<template>
  <div class="px-4 py-4 pb-16 space-y-4">
    <div class="flex items-center gap-3">
      <button @click="router.back()" class="text-panda-700 text-lg">←</button>
      <h1 class="text-2xl font-extrabold">Solicitudes</h1>
    </div>

    <div v-if="cargando" class="text-center py-16 text-slate-400">Cargando...</div>
    <div v-else-if="items.length === 0" class="card p-8 text-center text-slate-400">
      <div class="text-4xl mb-2">📭</div>
      No hay solicitudes pendientes
    </div>
    <div v-else class="space-y-3">
      <div v-for="s in items" :key="s.id" class="card p-4">
        <div class="flex items-start gap-3">
          <div class="flex-1 min-w-0">
            <div class="font-bold text-lg">{{ s.nombre }}</div>
            <div class="text-xs text-slate-500">📱 {{ s.telefono }} · {{ fmtDia(s.created_at) }}</div>
          </div>
          <div class="text-right">
            <div class="text-2xl font-extrabold text-panda-700">{{ fmt(s.monto_solicitado) }}</div>
            <div class="text-xs text-slate-500">{{ s.plazo_meses }} meses</div>
          </div>
        </div>
        <div v-if="s.motivo" class="text-sm text-slate-700 bg-slate-50 rounded-xl p-3 mt-3 italic">"{{ s.motivo }}"</div>
        <button @click="seleccionada = s; tasa = 15; mora = 50; respNotas = ''" class="btn-primary w-full mt-3">Revisar</button>
      </div>
    </div>

    <!-- Modal responder -->
    <div v-if="seleccionada" class="fixed inset-0 bg-black/50 z-30 flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div class="bg-white rounded-t-3xl sm:rounded-3xl w-full max-w-md p-6 space-y-4 max-h-[95vh] overflow-y-auto">
        <div class="flex justify-between items-center">
          <h3 class="text-xl font-extrabold">{{ seleccionada.nombre }}</h3>
          <button @click="seleccionada = null" class="text-slate-400 text-2xl">×</button>
        </div>
        <div class="card p-4 bg-panda-50 border-panda-200">
          <div class="text-3xl font-extrabold text-panda-700">{{ fmt(seleccionada.monto_solicitado) }}</div>
          <div class="text-sm text-slate-600 mt-1">📅 {{ seleccionada.plazo_meses }} meses</div>
          <div v-if="seleccionada.motivo" class="text-sm italic mt-2">"{{ seleccionada.motivo }}"</div>
        </div>
        <div class="text-sm font-bold text-slate-500 uppercase tracking-wider">Si apruebas</div>
        <div class="grid grid-cols-2 gap-3">
          <label for="s-tasa" class="block">
            <span class="text-sm font-semibold">Interés</span>
            <div class="relative mt-1">
              <input id="s-tasa" v-model.number="tasa" type="number" step="1" class="input pr-8" />
              <span class="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 font-bold">%</span>
            </div>
          </label>
          <label for="s-mora" class="block">
            <span class="text-sm font-semibold">Mora/día</span>
            <input id="s-mora" v-model.number="mora" type="number" step="10" class="input mt-1" />
          </label>
        </div>
        <label for="s-notas" class="block">
          <span class="text-sm font-semibold text-slate-600">Notas / mensaje al cliente</span>
          <textarea id="s-notas" v-model="respNotas" rows="2" class="input mt-1" placeholder="Ej: Recoge el efectivo mañana"></textarea>
        </label>
        <div class="grid grid-cols-2 gap-3">
          <button @click="responder('rechazar')" :disabled="guardando" class="btn-danger w-full">Rechazar</button>
          <button @click="responder('aprobar')" :disabled="guardando" class="btn-primary w-full">✓ Aprobar</button>
        </div>
      </div>
    </div>
  </div>
</template>
