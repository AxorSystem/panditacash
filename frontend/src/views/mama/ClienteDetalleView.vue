<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import api from '@/lib/api';
import { fmt, fmtDia, fmtHora } from '@/lib/format';
import ScoreBadge from '@/components/ScoreBadge.vue';

const props = defineProps<{ id: string }>();
const router = useRouter();

const data = ref<any>(null);
const cargando = ref(true);
const editando = ref(false);
const notasEdit = ref('');

async function cargar() {
  cargando.value = true;
  const r = await api.get(`/clientes/${props.id}`);
  data.value = r.data;
  notasEdit.value = data.value.cliente.notas ?? '';
  cargando.value = false;
}
onMounted(cargar);

async function guardarNotas() {
  await api.patch(`/clientes/${props.id}`, { notas: notasEdit.value });
  data.value.cliente.notas = notasEdit.value;
  editando.value = false;
}

const estadoIcon: Record<string, string> = {
  activo: '💰', liquidado: '✅', cancelado: '❌',
};
const estadoBg: Record<string, string> = {
  activo: 'bg-panda-100 text-panda-800',
  liquidado: 'bg-emerald-100 text-emerald-800',
  cancelado: 'bg-slate-200 text-slate-700',
};
</script>

<template>
  <div v-if="cargando" class="text-center py-20 text-slate-400">Cargando...</div>
  <div v-else-if="data" class="px-4 py-4 space-y-4">
    <div class="flex items-center gap-3">
      <button @click="router.back()" class="text-panda-700 text-lg">←</button>
      <h1 class="text-xl font-extrabold flex-1 truncate">{{ data.cliente.nombre }}</h1>
    </div>

    <!-- Score -->
    <ScoreBadge v-if="data.score" :score="data.score" />

    <!-- Ficha del cliente -->
    <div class="card p-5 flex items-center gap-4">
      <div class="w-16 h-16 rounded-full bg-gradient-to-br from-panda-400 to-panda-600 flex items-center justify-center text-white font-extrabold text-xl">
        {{ data.cliente.nombre.split(' ').map((x: string) => x[0]).slice(0, 2).join('').toUpperCase() }}
      </div>
      <div class="flex-1 min-w-0">
        <div class="font-bold text-slate-900">{{ data.cliente.nombre }}</div>
        <a :href="`https://wa.me/${data.cliente.telefono}`" target="_blank" class="text-sm text-emerald-700 flex items-center gap-1">
          💬 {{ data.cliente.telefono }}
        </a>
        <div class="text-xs text-slate-400 mt-0.5">Cliente desde {{ fmtDia(data.cliente.created_at) }}</div>
      </div>
    </div>

    <!-- Notas privadas -->
    <div class="card p-4">
      <div class="flex items-center justify-between mb-2">
        <div class="text-xs font-bold text-slate-500 uppercase tracking-wider">Notas privadas</div>
        <button @click="editando = !editando" class="text-xs text-panda-700">{{ editando ? 'Cancelar' : 'Editar' }}</button>
      </div>
      <div v-if="!editando">
        <p v-if="data.cliente.notas" class="text-sm text-slate-700 whitespace-pre-wrap">{{ data.cliente.notas }}</p>
        <p v-else class="text-sm text-slate-400 italic">Sin notas</p>
      </div>
      <div v-else>
        <textarea v-model="notasEdit" rows="3" class="input" placeholder="Ej: Puntual, vive por la escuela, vecina de Rosa..."></textarea>
        <button @click="guardarNotas" class="btn-primary w-full mt-2 text-sm py-2">Guardar</button>
      </div>
    </div>

    <!-- Préstamos -->
    <div class="space-y-2">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1">Préstamos ({{ data.prestamos.length }})</div>
      <div v-if="data.prestamos.length === 0" class="card p-6 text-center text-slate-400 text-sm">Sin préstamos aún</div>
      <router-link v-for="p in data.prestamos" :key="p.id" :to="`/mama/prestamo/${p.id}`"
        class="card p-4 flex items-center gap-3 active:scale-[0.98] transition">
        <div class="text-2xl">{{ estadoIcon[p.estado] || '📄' }}</div>
        <div class="flex-1 min-w-0">
          <div class="font-bold">{{ fmt(p.principal) }}</div>
          <div class="text-xs text-slate-500">
            {{ p.plazo_meses }} meses · {{ (p.tasa_mensual * 100).toFixed(0) }}% · {{ fmtDia(p.fecha_inicio) }}
          </div>
        </div>
        <span :class="'chip ' + (estadoBg[p.estado] || 'bg-slate-100')">{{ p.estado }}</span>
      </router-link>
    </div>

    <!-- Historial de pagos -->
    <div class="space-y-2">
      <div class="text-sm font-bold text-slate-500 uppercase tracking-wider px-1">Historial de cobros ({{ data.movimientos.length }})</div>
      <div v-if="data.movimientos.length === 0" class="card p-6 text-center text-slate-400 text-sm">Sin cobros registrados</div>
      <div v-for="m in data.movimientos" :key="m.id" class="card p-3 flex items-center gap-3">
        <div class="text-xl">💵</div>
        <div class="flex-1 min-w-0">
          <div class="font-bold text-slate-900">{{ fmt(Number(m.monto_capital) + Number(m.monto_mora)) }}</div>
          <div class="text-xs text-slate-500">
            {{ fmtHora(m.fecha_pago) }} · {{ m.metodo }}
            <span v-if="Number(m.monto_mora) > 0"> · {{ fmt(m.monto_mora) }} mora</span>
          </div>
          <div v-if="m.notas" class="text-xs text-slate-600 mt-1 italic truncate">"{{ m.notas }}"</div>
        </div>
      </div>
    </div>
  </div>
</template>
