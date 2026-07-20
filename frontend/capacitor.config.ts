import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.axorsystem.panditacash',
  appName: 'PanditaCash',
  webDir: 'dist',
  bundledWebRuntime: false,
  // Modo LOCAL: los assets van embebidos en el APK/IPA. La UI abre siempre
  // (aunque no haya internet). Solo el API es remoto.
  server: {
    androidScheme: 'https',
    iosScheme: 'capacitor',
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 1500,
      launchAutoHide: true,
      backgroundColor: '#FFF5E4',
      androidSplashResourceName: 'splash',
      showSpinner: false,
    },
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#F59E0B',
    },
  },
  ios: {
    contentInset: 'always',
    backgroundColor: '#FFF5E4',
  },
  android: {
    backgroundColor: '#FFF5E4',
    allowMixedContent: false,
  },
};

export default config;
