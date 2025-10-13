# Emacs development loop

This module wires Emacs into a "Codex-like" workflow that stays fully local to
NixOS/Home-Manager while still giving you AI-assisted editing, repo-aware chat
and patching, and the usual Magit/Forge Git tooling.

## Prerequisites

* **Secrets** – store your OpenAI-compatible key in pass as
  `openai/api-key` or export `OPENAI_API_KEY` before launching Emacs.  The
  `gptel` helpers read from pass automatically when available.
* **Copilot** – authenticate once with `M-x copilot-login` and install the
  language server with `M-x copilot-install-server` (Node.js is provided by the
  module).
* **Direnv** – add a project-local `.envrc` containing `use flake` (or your
  preferred Nix direnv stanza) and run `direnv allow` from a terminal.  The
  Emacs `envrc` minor mode is enabled globally so buffers pick up the sandboxed
  toolchains automatically.
* **Forge** – configure Magit Forge credentials the usual way (e.g. `gh auth
  login`).  The module adds GitHub's `gh` CLI to the profile for convenience.

After secrets are available, switch Home-Manager with:

```sh
home-manager switch --flake .#yourUser@yourHost
```

## Key bindings

| Binding | Scope | Action |
|---------|-------|--------|
| `C-c ]` | global | Accept the active Copilot completion. |
| `C-c g g` | global | Open a `gptel` chat buffer in Org mode. |
| `C-c g e` | global | Ask `gptel` to explain the selected region. |
| `C-c g b` | global | Summarise the current buffer with `gptel`. |
| `C-c g r` | global | Rewrite the active region via `gptel-rewrite`. |
| `C-c a a` | global | Open an aider session in a project-scoped `vterm`. |
| `C-c p ]` | projectile map | Toggle `copilot-mode` for the project. |
| `C-c p a` | projectile map | Launch aider in the project root. |

The existing Xah Fly Keys leader maps remain untouched, so the new bindings are
available even if you are using that modal layer.

## AI assisted editing

* **Completions** – `copilot-mode` hooks into `prog-mode`.  Use `TAB` (or
  `C-c ]`) to accept suggestions, `C-<tab>` for word-wise and `M-<tab>` for
  line-wise completions.
* **Region/file analysis** – the helper commands defined in
  `packages.el` (`crio/gptel-explain-region`,
  `crio/gptel-review-buffer`, `crio/gptel-refactor-region`) all route through
  `gptel` with a custom system prompt tuned for NixOS/Emacs development.  They
  produce results in dedicated `*gptel-…*` buffers so you can keep a running
  conversation per file.

## Repo-aware chat & patching

`C-c a a` (or `C-c p a`) creates a dedicated `vterm` in the current project's
root and starts `aider --model openai/gpt-4o-mini --no-auto-commit`.  The
buffer name includes the project, making it easy to keep multiple sessions.  A
prefix argument lets you edit the exact aider command before launch.

Inside aider you can:

1. Instruct it to draft a change (`/ask`, `/plan`, etc.).
2. Accept patches back into the repo.
3. Run tests from the same vterm, benefiting from the project's `direnv`
   sandbox.

## Git, testing and PRs

* Use `magit-status` (`SPC m` in the Xah Fly leader map or `M-x magit-status`)
  to stage changes.  `forge` is already installed, so `#` in the status buffer
  will create or visit the associated pull request.
* `vterm` inherits the project sandbox, so test commands (e.g. `nix flake
  check`, `just test`, etc.) run in the correct environment.
* Finish by committing in Magit and pushing/raising a PR with Forge.

Following this loop you can `gptel` for guidance, `aider` for patches, test in a
sandboxed shell, and close everything out via Magit – all without leaving
Emacs.
