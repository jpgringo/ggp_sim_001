import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './assets/styles/main.scss'
import App from './App.vue'

const pinia = createPinia();
const app = createApp(App);
app.use(createPinia());
app.mount('#app')
