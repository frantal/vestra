# VESTRA — Plano de Execução

> Plataforma inteligente de gestão de guarda-roupa com IA · FranTal Company
> Stack: **Flutter** (Android / iOS / Web) + **Supabase** + **OpenAI / Gemini / Google ML Kit**

---

## Visão do Produto

Um **assistente de guarda-roupa com IA**. Tema escuro premium (fundo `#0B0F1A`, primário ciano `#00D4FF`, accent `#34E5FF`, glassmorphism, glow neon, raio 20px, animações 300ms). Arquitetura Clean / feature-first / MVVM com Riverpod.

**Fluxo central:** Splash → Onboarding → Login/Registo → Permissões → Setup inicial → Digitalização (IA reconhece peças) → Dashboard → uso diário (Guarda-roupa, IA stylist, Espelho IA, Histórico, Estatísticas).

---

## Plano por Fases

### Fase 0 — Fundações (setup do projeto) ✅ CONCLUÍDA
- [x] Projeto Flutter criado (Android/iOS/Web), `pubspec.yaml` com o stack.
- [x] Estrutura de pastas `core/` + `features/` + `shared/`.
- [x] `analysis_options.yaml` com lints rigorosos — **análise limpa**.
- [x] **Design System**: cores, tipografia (Inter), espaçamentos, tema escuro.
- [x] Componentes base: `GlassCard`, `GlowButton`, skeleton/loading/empty/error.
- [x] Smoke test a passar.

> Nota: plugins nativos pesados (Supabase, câmara, ML Kit, geolocator,
> permission_handler) estão comentados no `pubspec.yaml` (secção "Fase 3+")
> devido à rede instável — reativar quando forem necessários.

### Fase 1 — Navegação & Shell ✅ CONCLUÍDA
- [x] GoRouter com `StatefulShellRoute.indexedStack` + provider Riverpod.
- [x] Splash animado que encaminha para o shell.
- [x] Bottom bar de 5 slots (Home, Guarda-Roupa, **+**, IA, Perfil).
- [x] Ecrãs placeholder por feature + fluxo `+` full-screen.
- [x] Estados reutilizáveis (Loading / Empty / Error / Skeleton) já disponíveis.
- [x] Análise limpa e smoke test de navegação a passar.

### Fase 2 — Onboarding & Autenticação ✅ CONCLUÍDA (UI)
- [x] Onboarding de 4 páginas (PageView + dots + "Saltar") com flag persistida.
- [x] Login (Email/Senha + Google/Apple/Facebook + "Esqueci a senha").
- [x] Criar Conta (Nome/Email/Senha).
- [x] Ecrã de Permissões (câmara, fotos, notificações, localização, calendário).
- [x] Splash decide destino via `shared_preferences` (onboarding vs login).
- [x] Análise limpa e teste do fluxo a passar.

> Auth real (Supabase) e pedidos de permissão do SO ficam para a Fase 3.

### Fase 3 — Backend & Base de Dados (Supabase) ✅ CONCLUÍDA
- Schema PostgreSQL: `profiles`, `clothing_items`, `categories`, `outfits`, `outfit_items`, `usage_history`, `wash_history`, `tags`.
- UUIDs, soft-deletes, campos de auditoria, índices, FKs, **RLS** ativo.
- Storage para fotos + políticas. Camada repository com cache offline (Hive).

> **Feito:** migração SQL completa em `supabase/migrations/0001_initial_schema.sql`
> (tabelas, triggers `updated_at`, `handle_new_user`, RLS por dono, bucket `wardrobe`).
> Integração Dart: `SupabaseConfig` (chaves via `--dart-define`, nunca hardcoded),
> `Supabase.initialize()` condicional em `main.dart`, camada de auth
> (`AuthRepository` + `SupabaseAuthRepository` + providers Riverpod).
> Ecrãs de login/registo ligados à auth real com estados de loading/erro inline
> e fallback UI quando não há backend configurado.
>
> **Pendente do utilizador:** criar projeto Supabase, correr a migração no SQL Editor,
> e correr a app com `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
> Cache offline Hive nas peças fica para a Fase 5 (CRUD).


### Fase 4 — Setup Inicial & Digitalização
- Questionário (sexo, idade, estilo, cores favoritas, nº de peças).
- Captura de peça (câmara/galeria) + barra de progresso da digitalização.

### Fase 5 — Guarda-Roupa (CRUD)
- Listagem por categorias + filtros (cor, estado, marca, estação, ocasião).
- Página da peça (foto, estado, utilizações, última lavagem/uso) + ações (editar, lavada, usada, remover).

### Fase 6 — IA (núcleo do produto)
- Reconhecimento por foto (Google ML Kit local → OpenAI/Gemini para enriquecer: categoria, cor, manga, ocasião).
- Assistente de linguagem natural (estilo chat).
- Recomendação de outfits (estilo + clima + ocasião + histórico, evitando repetição).
- **Espelho IA**: selfie → score do look + sugestões.
- Edge Functions no Supabase para chamadas seguras às APIs (chaves nunca no cliente).

### Fase 7 — Histórico, Estatísticas & Notificações
- Calendário de uso, dashboard de stats (peça/cor/marca favorita, peças esquecidas, dias sem repetir).
- Notificações contextuais (clima, lavagem, repetição).

### Fase 8 — Perfil, Definições & Premium
- Perfil, tema, idioma, backup/exportar/sincronizar.
- Definições (IA, notificações, privacidade, conta).
- Estrutura para plano Premium.

### Fase 9 — Qualidade & Lançamento
- Testes (unit/widget/integration), acessibilidade, responsividade.
- Otimização de performance, offline-first, hardening de segurança (OWASP).
- Build Android/iOS, ícones, splash nativo, store assets.

---

## Princípios de Engenharia
- Cada feature contém: **Presentation · Application · Domain · Infrastructure**.
- Riverpod como único state management.
- Repository Pattern + Dependency Injection.
- Código production-ready, testável, sem duplicação.

## Sugestões de melhoria
1. **Segurança de chaves de IA**: passar sempre por Edge Functions — nunca embeber chaves no app.
2. **Custo de IA**: cachear reconhecimentos e usar ML Kit local primeiro, recorrendo a LLM só para enriquecer.
3. **Feature flags** desde o início (Premium, Espelho IA) para lançar incrementalmente.

---

## Design System (referência)
| Token | Valor |
|---|---|
| Background | `#0B0F1A` |
| Surface | `#131A27` |
| Primary | `#00D4FF` |
| Accent | `#34E5FF` |
| Text | `#FFFFFF` |
| Secondary Text | `#A5B4C3` |
| Border Radius | `20px` |
| Animation | `300ms` |
