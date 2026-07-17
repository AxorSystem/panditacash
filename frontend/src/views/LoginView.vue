<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const auth = useAuthStore();

type Modo = 'elegir' | 'mama-pin' | 'cliente-tel' | 'cliente-otp';
const modo = ref<Modo>('elegir');

const telefono = ref('');
const nombre = ref('');
const pin = ref('');
const otp = ref('');

const cargando = ref(false);
const error = ref('');
const requiereNombre = ref(false);
const mensajeEnvio = ref('');

async function loginMama() {
  error.value = '';
  cargando.value = true;
  try {
    await auth.loginMama(telefono.value, pin.value);
    router.push('/');
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Error';
  } finally { cargando.value = false; }
}

const BOT_WA = '525525034846';

const waLink = computed(() => {
  const tel = telefono.value.replace(/\D/g, '');
  return `https://wa.me/${BOT_WA}?text=${encodeURIComponent(`PANDITA-${tel}`)}`;
});

async function registrarSiNuevo() {
  error.value = '';
  cargando.value = true;
  try {
    // Solo dispara para asegurar que el user exista en DB antes del WA
    await auth.requestOtp(telefono.value, nombre.value);
    modo.value = 'cliente-otp';
    const tel = telefono.value.replace(/\D/g, '');
    mensajeEnvio.value = `✅ Abre WhatsApp con el botón y envía "PANDITA-${tel}". Recibirás tu código.`;
  } catch (e: any) {
    const msg = e.response?.data?.error ?? 'Error';
    if (msg.includes('no está registrado')) {
      requiereNombre.value = true;
      error.value = 'Escribe tu nombre para registrarte.';
    } else {
      error.value = msg;
    }
  } finally { cargando.value = false; }
}

async function validarOtp() {
  error.value = '';
  cargando.value = true;
  try {
    await auth.verifyOtp(telefono.value, otp.value);
    router.push('/');
  } catch (e: any) {
    error.value = e.response?.data?.error ?? 'Error';
  } finally { cargando.value = false; }
}
</script>

<template>
  <div class="min-h-screen flex flex-col justify-center px-6 py-8 bg-gradient-to-br from-panda-50 via-white to-panda-100">
    <!-- Header/branding -->
    <div class="text-center mb-10">
      <img src="/logo.svg" alt="PanditaCash" class="w-28 h-28 mx-auto mb-4 drop-shadow-lg" />
      <h1 class="text-4xl font-extrabold bg-gradient-to-r from-panda-500 to-panda-700 bg-clip-text text-transparent tracking-tight">PanditaCash</h1>
      <p class="text-slate-600 mt-2 text-sm font-medium">Préstamos con corazón 🐼</p>
    </div>

    <!-- Elegir tipo -->
    <div v-if="modo === 'elegir'" class="space-y-3">
      <button @click="modo = 'mama-pin'" class="w-full bg-gradient-to-r from-panda-500 to-panda-600 text-white font-bold rounded-3xl py-5 shadow-lg shadow-panda-500/30 active:scale-[0.97] transition">
        👩 Soy mamá (administradora)
      </button>
      <button @click="modo = 'cliente-tel'" class="w-full bg-white border-2 border-panda-200 text-ink font-bold rounded-3xl py-5 hover:border-panda-500 active:scale-[0.97] transition">
        🙋 Soy cliente
      </button>
      <p class="text-center text-xs text-slate-500 mt-6">Tu información está segura y privada.</p>
    </div>

    <!-- Login mamá con PIN -->
    <div v-if="modo === 'mama-pin'" class="space-y-4">
      <button @click="modo = 'elegir'" class="text-panda-700 text-sm">← Cambiar</button>
      <div class="card p-6 space-y-4">
        <h2 class="text-xl font-bold text-center">Hola mamá 👋</h2>
        <label for="tel-mama" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu teléfono</span>
          <input id="tel-mama" v-model="telefono" type="tel" inputmode="numeric" placeholder="55 XXXX XXXX" class="input mt-1" />
        </label>
        <label for="pin-mama" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu PIN (4 dígitos)</span>
          <input id="pin-mama" v-model="pin" type="password" inputmode="numeric" maxlength="6" placeholder="••••" class="input mt-1 text-center tracking-widest text-3xl" />
        </label>
        <p v-if="error" class="text-red-600 text-sm text-center">{{ error }}</p>
        <button @click="loginMama" :disabled="cargando" class="btn-primary w-full">
          {{ cargando ? 'Entrando...' : 'Entrar' }}
        </button>
      </div>
    </div>

    <!-- Login cliente teléfono -->
    <div v-if="modo === 'cliente-tel'" class="space-y-4">
      <button @click="modo = 'elegir'" class="text-panda-700 text-sm">← Cambiar</button>
      <div class="card p-6 space-y-4">
        <h2 class="text-xl font-bold text-center">Bienvenido</h2>
        <p class="text-sm text-slate-500 text-center">Recibirás un código por WhatsApp.</p>
        <label for="tel-cli" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu teléfono (10 dígitos)</span>
          <input id="tel-cli" v-model="telefono" type="tel" inputmode="numeric" placeholder="55 XXXX XXXX" class="input mt-1" />
        </label>
        <label v-if="requiereNombre" for="nom-cli" class="block">
          <span class="text-sm font-semibold text-slate-600">Tu nombre completo</span>
          <input id="nom-cli" v-model="nombre" placeholder="Ej: Liliana Martínez" class="input mt-1" />
        </label>
        <p v-if="error" class="text-red-600 text-sm text-center">{{ error }}</p>
        <button @click="registrarSiNuevo" :disabled="cargando || telefono.replace(/\D/g,'').length < 10" class="btn-primary w-full">
          {{ cargando ? 'Cargando...' : 'Continuar' }}
        </button>
      </div>
    </div>

    <!-- Validar OTP -->
    <div v-if="modo === 'cliente-otp'" class="space-y-4">
      <button @click="modo = 'cliente-tel'" class="text-panda-700 text-sm">← Cambiar teléfono</button>
      <div class="card p-6 space-y-4">
        <h2 class="text-xl font-bold text-center">Recibe tu código</h2>

        <!-- Paso 1: enviar mensaje al bot -->
        <div class="space-y-2">
          <div class="flex items-center gap-2">
            <div class="w-6 h-6 rounded-full bg-panda-500 text-white flex items-center justify-center font-bold text-sm">1</div>
            <span class="text-sm font-semibold text-slate-700">Abre WhatsApp y envía el mensaje</span>
          </div>
          <a :href="waLink" target="_blank" rel="noreferrer"
             class="block w-full bg-emerald-500 hover:bg-emerald-600 text-white font-bold py-4 rounded-2xl text-center active:scale-[0.97] transition shadow-lg shadow-emerald-500/30">
            💬 Abrir WhatsApp
          </a>
          <p class="text-xs text-slate-500 text-center">
            Se abrirá con el mensaje "<b>PANDITA-{{ telefono.replace(/\D/g,'') }}</b>" precargado. Solo toca <b>Enviar</b> ↗
          </p>
        </div>

        <!-- Paso 2: recibir código y meterlo -->
        <div class="space-y-2 border-t border-panda-100 pt-4">
          <div class="flex items-center gap-2">
            <div class="w-6 h-6 rounded-full bg-panda-500 text-white flex items-center justify-center font-bold text-sm">2</div>
            <span class="text-sm font-semibold text-slate-700">Escribe aquí el código que te llegó</span>
          </div>
          <label for="otp-cli" class="block">
            <input id="otp-cli" v-model="otp" type="tel" inputmode="numeric" maxlength="6" placeholder="000000" class="input mt-1 text-center tracking-widest text-3xl" />
          </label>
          <p v-if="error" class="text-red-600 text-sm text-center">{{ error }}</p>
          <button @click="validarOtp" :disabled="cargando || otp.length !== 6" class="btn-primary w-full">
            {{ cargando ? 'Validando...' : 'Entrar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
