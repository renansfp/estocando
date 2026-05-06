# Protecin Produção

> Production management system for fire extinguisher maintenance — running live in an active factory.

Built with Flutter and Firebase, this system controls the full maintenance cycle of fire extinguishers — from intake at the factory to dispatch back to the client — with complete traceability, integrated inventory control, and automatic PDF technical report generation.

---

## What it does

A fire extinguisher arrives at the factory and gets a temporary tracking tag (cracha). From that moment, every step of its maintenance journey is tracked in real time across 11 production stations:

```
Intake → Discharge → Cleaning → Valve Maintenance → Hydrostatic Test →
Sanding → Painting → Recharge → Assembly → Pre-Assembly → Dispatch
```

Each station has its own screen for operators (Android mobile), while management uses a Windows desktop dashboard to monitor everything in real time.

---

## Key features

- **11-station production flow** — each station has its own operator screen with real-time status
- **Atomic stock transactions** — inventory is validated, debited, and logged in a single operation; no record is ever deleted (full audit trail)
- **Automatic PDF technical reports** — 28-column landscape layout with complete service history per fire extinguisher
- **Internal requisition system** — operators request materials from the warehouse with pending queue and alert badges
- **Argox label printing** — NR23 compliance labels and warranty labels, via local USB or cloud print queue (Windows service)
- **Real-time dashboards** — per-station counters showing live production status
- **Batch lot control** — chemical powder lots tracked with batch number and expiration date
- **Firebase Auth** — user registration with manual approval and role-based access
- **Multi-platform** — Android for factory operators, Windows desktop for management

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend / App | Flutter (Material 3) |
| State management | Provider + ChangeNotifier |
| Database | Firebase Firestore (real-time NoSQL) |
| Authentication | Firebase Auth |
| PDF generation | `pdf` + `printing` packages |
| Label printing | Argox PPLA protocol (serial/USB) |
| Architecture | Repository Pattern with abstract contracts |
| Platforms | Android + Windows desktop |

---

## Architecture

The project follows a strict **Repository Pattern** with three layers:

```
Screen / Widget
    ↓ calls
Provider (state management)
    ↓ calls
Repository (only layer that touches the database)
```

9 repositories implemented:
`EquipamentoRepository`, `ItemOsRepository`, `OrdemServicoRepository`,
`ParceiroRepository`, `MovimentacaoRepository`, `ProdutoRepository`,
`RequisicaoRepository`, `UsuarioRepository`, `PrintJobRepository`

---

## Firebase collections

| Collection | Contents |
|---|---|
| `ordens_servico` | Service orders — groups extinguishers from one client |
| `itens_os` | Each extinguisher within an order, with status and technical data |
| `equipamentos` | Client extinguisher registry (permanent assets) |
| `crachas` | Temporary tracking tags (R-001 to R-1500) |
| `movimentacoes` | Stock entries and exits with full audit trail |
| `produtos` | Warehouse catalog (valves, powder, CO2, parts) |
| `lotes` | Controlled product lots (chemical powder with batch and expiry) |
| `requisicoes` | Internal material requests (operator → warehouse) |
| `parceiros` | Clients and suppliers |
| `usuarios` | User profiles with approval and role-based access |
| `print_jobs` | Argox label print queue |

---

## Project status

This system is **in active production use** at a fire extinguisher maintenance company in Santo André, SP — Brazil. It is used daily by real operators on the factory floor.

Current focus: capturing technical measurement data during production stages to enable fully automatic PDF report generation (hydrostatic test pressures, valve weights, recharge volumes).

---

## About the author

Built by **Renan Szulcsewski Franco Pinto** — 20 years of experience in industrial operations, procurement, and production management. This project was designed from the ground up based on real factory floor knowledge, developed with Flutter and AI-assisted engineering.

📍 Santo André, SP — Brazil  
🔗 [LinkedIn](https://www.linkedin.com/in/renansfp)  
📧 Open to remote work opportunities

---

> **Note:** The `firebase_options.dart` file is excluded from this repository for security reasons. To run this project locally you will need to configure your own Firebase project and generate your own `firebase_options.dart` using the FlutterFire CLI.
