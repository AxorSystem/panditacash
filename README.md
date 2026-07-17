# 🐼 PanditaCash

Sistema de préstamos personales con recordatorios automáticos por WhatsApp.

## Reglas del negocio

- **Interés variable** (mamá elige % al aprobar cada préstamo, típico 10-20% mensual)
- **Cobro anticipado del primer interés**: al entregar, retiene el interés del mes 1
- **Meses intermedios**: cliente paga solo el interés
- **Último mes**: cliente paga el principal completo
- **Mora diaria**: configurable por préstamo (mamá decide cobrarla o perdonarla)

## Ejemplo

Liliana pide $10,000 a 3 meses al 15%:

| Momento | Liliana paga | Mamá recibe | Saldo |
|---|---|---|---|
| Día 0 | — | Entrega $8,500 (retiene $1,500 mes 1) | Debe $10,000 |
| Mes 2 | $1,500 | $1,500 | Debe $10,000 |
| Mes 3 | $10,000 | $10,000 | ✓ Liquidado |

Ganancia mamá: **$3,000 en 3 meses** por prestar $10,000.

## Stack

- **Backend**: Node 20 + Express + TypeScript + SQL Server
- **Frontend**: Vue 3 + Vite + Tailwind, mobile-first
- **Auth**: PIN 4 dígitos (mamá) · WhatsApp OTP (clientes)
- **Notificaciones**: WhatsApp automatizado (via notifications-backend)
- **Deploy**: Coolify + Hetzner

## URLs

- Frontend: https://panditacash.5-78-222-255.sslip.io/
- Backend: https://api-panditacash.5-78-222-255.sslip.io/api/health
