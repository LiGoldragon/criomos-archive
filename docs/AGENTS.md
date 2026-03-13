# Repository Guidelines

## Project Structure & Module Organization
- Root Nix entrypoints live in `flake.nix` and `default.nix`.
- Core system modules are under `nix/mkCriomOS/`; zone and sphere builders live in `nix/mkCrioZones/` and `nix/mkCrioSphere/`.
- Home Manager modules are in `nix/homeModule/` (with `min/`, `med/`, `max/` profiles).
- Package and tooling overlays are in `nix/pkdjz/` and `nix/mkPkgs/`.
- Schema definitions are in `capnp/`; website templates live in `mkWebpage/`.
- Inputs are pinned in `npins/` and `flake.lock`.

## Build, Test, and Development Commands
- For operator work, prefer exact attr builds over broad flake evaluation.
- `nix build .#crioZones.maisiliym.ouranos.os --no-link --print-out-paths --refresh` builds the current Ouranos system payload.
- `nix build .#crioZones.maisiliym.prometheus.os --no-link --print-out-paths --refresh` builds the current Prometheus system payload.
- `nix build .#crioZones.maisiliym.ouranos.deployManifest --no-link --print-out-paths --refresh` builds the Ouranos deployment manifest.
- `nix build .#crioZones.maisiliym.prometheus.deployManifest --no-link --print-out-paths --refresh` builds the Prometheus deployment manifest.
- `execute deploy-manifest --manifest $(nix build .#crioZones.maisiliym.<node>.deployManifest --no-link --print-out-paths --refresh) --node <node>` is the canonical activation shape.
- Temporary transport ladder: the generated manifest prefers Yggdrasil first; `--allow-localhost` is override-only and must succeed through a `hostname == nodeName` guard before any local activation proceeds.
- `nix develop` remains the entry point when an interactive development shell is needed.

## Coding Style & Naming Conventions
- Adhere to the Nix-specific Sema object style defined in `NIX_GUIDELINES.md`. The universal principles, with their original Rust examples, are in `GUIDELINES.md` for context.
- Nix files use 2-space indentation and prefer the existing formatting in the file.
- Formatting tools seen in this repo include `nixpkgs-fmt` and `nixfmt-rfc-style`; use the one already used in the area you touch.

## Testing Guidelines
- Nix evaluation tests live in `nix/tests/`.
- Prefer adding or updating tests alongside module changes, then validate with `nix flake check`.

## Node/Network Truth Guidance
- `Components/CriomOS/docs/GUIDELINES.md` is the canonical operator reference for node/network behavior. Read the `Operator Node/Network Truth Authority` section and respect the **MUST UPDATE WHEN EDITING REPO** marker before touching network or horizon code.
- Maisiliym owns node/network truth in `/home/li/git/maisiliym/datom.nix` (`NodeProposal.nodes.*`). CriomOS consumes/builds/deploys the resulting horizon exports from `Components/CriomOS/nix/mkCrioZones/mkHorizonModule.nix`, with network modules such as `Components/CriomOS/nix/mkCriomOS/network/default.nix` and `Components/CriomOS/nix/mkCriomOS/network/unbound.nix` deriving their host data from that truth.

## Commit & Pull Request Guidelines
- Commit messages follow a lowercase verb + scoped parentheses style, often nested (example: `fix(emacs(errors(copilot)))`).
- PRs should include a short intent summary, affected outputs (e.g., `nix/mkCriomOS`), and the exact test commands run.
- Include screenshots when changing `mkWebpage/` templates.

## Agent-Specific Instructions
- Follow `AGENT_RULES.md`: ALL CAPS paths are immutable; PascalCase paths are stable contracts; lowercase paths are mutable.
