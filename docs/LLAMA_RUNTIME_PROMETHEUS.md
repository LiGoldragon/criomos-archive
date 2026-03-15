# LLAMA PROMETHEUS RUNTIME (SEMA-PROGRAMMER NOTES)

Scope
- Components/CriomOS only. Documents the exact, repo-local systemd Environment override and deterministic verification for the Prometheus "llama" runtime.

## Overview
The Prometheus runtime deploys one llama.cpp-based server per model using generated systemd units produced by Components/CriomOS/nix/mkCriomOS/llm.nix. The runtime binary package is Components/CriomOS/nix/llama-cpp-prometheus.nix.

## Build target

Note: runtime systemd User and HOME are derived from repo-local authority (horizon and config.users) by Components/CriomOS/nix/mkCriomOS/llm.nix. The module prefers users that explicitly target the current node (horizon.users entries whose preCriomes include this node); if none match it falls back to broader horizon/global user definitions and finally to the first user defined in config.users.users. No literal "/home/li" or "li" is hardcoded in the module.
The exact Nix build target that produces the generated systemd units referenced in this document is:

.#crioZones.maisiliym.prometheus.os

Build and inspectable output is produced by building that attribute from Components/CriomOS.

## Why HSA_OVERRIDE_GFX_VERSION is present
On certain hosts (e.g. devices reporting gfx1151) the ROCm userland used here does not enumerate the device without an HSA override. The repository-local, minimal change applied in mkCriomOS/llm.nix adds an Environment entry to the generated systemd units:

HSA_OVERRIDE_GFX_VERSION=11.5.1

This environment entry is applied only to the spawned llama server process (systemd unit Environment=). It is a reversible, process-scoped mitigation; no changes to global host packages or kernels are made by this repository change.

## Exact observed failure and fallback signatures in this project
When ROCm enumeration fails in the runtime observed in this repository, the following exact log lines have been produced by the llama/ggml processes (copy-paste exact matches):

- ggml_cuda_init: failed to initialize ROCm: no ROCm-capable device is detected
- warning: no usable GPU found, --gpu-layers option will be ignored

In addition, when the binary falls back to CPU buffers the logs include the CPU buffer fallback lines emitted by ggml/llama (these appear after ROCm failure lines and indicate the process is running on CPU memory).

These exact strings above are the deterministic evidence used in this repo to identify a ROCm-enumeration failure and CPU fallback.

## Deterministic success verification
A successful ROCm-enabled start of the llama runtime (with the override in effect) is deterministically visible in the server logs by the presence of the ggml/ROCm init success lines and the absence of the fallback warnings. Concretely, success is identified by:

- A ggml/ROCm init line such as: ggml_cuda_init: found 1 ROCm devices (or a line beginning with "ggml_cuda_init: found" describing device count/name).
- Absence of the failure signatures listed above (no occurrences of the exact strings:
  - "ggml_cuda_init: failed to initialize ROCm: no ROCm-capable device is detected"
  - "warning: no usable GPU found, --gpu-layers option will be ignored")

If those success lines appear and the fallback warnings do not, the process is using ROCm devices for GPU layers.

## Service names and ports (current Prometheus lanes)
- prometheus-llama-sanity → port 11436
- prometheus-llama-reasoning → port 11437
- gateway (prometheus-litellm / proxy) → port 11434

The two llama services above are the ROCm consumers; the gateway is a proxy and does not itself drive ROCm device enumeration for model inference.

## Reproducible verification commands (repo-local, deterministic)
1) Build the production OS target and capture its output path (run from repository root):

cd Components/CriomOS && out=$(nix build --no-link --print-out-paths .#crioZones.maisiliym.prometheus.os) && echo "$out"

This prints the produced Nix output path (e.g. /nix/store/<hash>-...-crioZones-maisiliym-prometheus-os).

2) Inspect the generated systemd units inside that built output (no deployment required). Do NOT run systemctl against files in the build output path. Instead, inspect the unit files directly with file inspection tools against the built output (replace $out with the printed path). Example reproducible commands:

# inspect with sed (show entire unit or specific lines)
sed -n '1,200p' "$out/etc/systemd/system/prometheus-llama-reasoning.service"

# or use grep to find the environment entry deterministically
grep -n "HSA_OVERRIDE_GFX_VERSION" "$out/etc/systemd/system/prometheus-llama-"*.service

3) Runtime verification on the deployed/target host (out-of-scope to run here but reproducible):
- Start the service: systemctl start prometheus-llama-reasoning
- Follow logs: journalctl -u prometheus-llama-reasoning -f --no-hostname
- Look for success signature: a line beginning with "ggml_cuda_init: found" and confirm there are no occurrences of the exact failure strings listed above.

Example deployed-host checks:
- Inspect the active unit on the host (deployed): systemctl cat prometheus-llama-reasoning
- Check logs on the host: journalctl -u prometheus-llama-reasoning | grep -E "ggml_cuda_init: found|ggml_cuda_init: failed to initialize ROCm|warning: no usable GPU found"

## Implementation references
- Service generation: Components/CriomOS/nix/mkCriomOS/llm.nix (where Environment insertion occurs)
- Binary package: Components/CriomOS/nix/llama-cpp-prometheus.nix
- Model lock/catalog: Components/CriomOS/data/config/pi/prometheus-model-lock.json

## Change record
- Repository-local change: mkCriomOS/llm.nix adds Environment HSA_OVERRIDE_GFX_VERSION=11.5.1 to the generated prometheus llama systemd units.

End of document.
