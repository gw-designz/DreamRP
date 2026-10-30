import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import { initSounds } from './services/sound.js'
import './styles/base.css'
import './styles/admin.css'
import './styles/dm.css'

initSounds()
createRoot(document.getElementById('root')).render(<App />)
