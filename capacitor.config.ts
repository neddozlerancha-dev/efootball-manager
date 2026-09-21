import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.efootball.tournamenthub',
  appName: 'eFootball Tournament Hub',
  webDir: 'www',
  bundledWebRuntime: false,
  server: {
    url: 'https://effulgent-trifle-f3b042.netlify.app',
    androidScheme: 'https',
    cleartext: false
  }
};

export default config;
