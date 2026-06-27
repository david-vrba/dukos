# DukOS — Disclaimer & Usage Notice

> **STATUS: DRAFT — Not reviewed by a lawyer. Do not treat this as legal advice.**
> This file is a placeholder. Have a qualified legal professional review before public release.

---

## 1. Use At Your Own Risk

DukOS is provided "as is" under the MIT License, without warranty of any kind. By running DukOS you accept full responsibility for:

- All actions taken by agents on your system and files
- All API costs incurred with Anthropic or any other provider
- Any data sent to third-party services

The maintainers are not liable for data loss, unexpected file modifications, API charges, or any other consequences of running DukOS.

---

## 2. Agents Run With Elevated Permissions

DukOS agents run using `--dangerously-skip-permissions`, which means they can:

- Read, write, and delete files on your system
- Execute shell commands
- Make network requests
- Install packages

**You are granting agents broad access to your machine.** Only run DukOS in an environment you control and trust. Review agent prompts before running. Never run DukOS as a root/admin user.

---

## 3. Data & Privacy — Where Your Data Goes

**DukOS v1 runs on Claude.** Every agent's inference goes through the Anthropic API or a Claude subscription. That means your conversation data — the prompts, the agent outputs, and the project files agents read into context — **leaves your device** and is processed on Anthropic's servers, subject to Anthropic's [Privacy Policy](https://www.anthropic.com/privacy) and [Terms](https://www.anthropic.com/legal/consumer-terms).

| Mode | Status | Where data goes | Leaves your device? |
|---|---|---|---|
| **Anthropic API / Claude subscription** (Opus/Sonnet/Haiku) | **Shipping (v1)** | Anthropic's servers | Yes — subject to Anthropic's [Privacy Policy](https://www.anthropic.com/privacy) and [ToS](https://www.anthropic.com/legal/consumer-terms) |
| **Local model via Ollama** (Gemma, Llama, etc.) | **Planned (roadmap)** | Your own machine only | Will stay 100% on-device — *once local mode ships* |
| **Remote Ollama** (another PC on your network) | **Planned (roadmap)** | That PC only | Will stay within your network — *once local mode ships* |

Running DukOS today means sending data to Anthropic. A fully-private, local-only mode (no conversation content, prompts, or outputs leaving your machine) is a **planned roadmap feature, not part of v1** — see the README's Roadmap section.

The principle holds for any model: when inference runs in the cloud, your prompts and the content agents read are transmitted to and processed by that provider; when a model runs locally, nothing leaves your machine.

---

## 4. Third-Party Model Terms

When using any AI model, you are also bound by that provider's terms:

| Provider | Key document |
|---|---|
| Anthropic (Claude) | [anthropic.com/legal](https://www.anthropic.com/legal/consumer-terms) |
| Google (Gemma 4 via Ollama) | [ai.google.dev/gemma/terms](https://ai.google.dev/gemma/terms) |
| Meta (Llama via Ollama) | [llama.meta.com/llama3/license](https://llama.meta.com/llama3/license/) |

> **Note on local models — applies once local mode ships:** Local-model support (Ollama) is a planned roadmap feature; **v1 of DukOS runs on Claude only**. When a local open-weight model (e.g. Gemma or Llama) is run via Ollama, it executes entirely on your device — the weights are downloaded once and run offline, so no conversation data leaves your machine. This note describes the planned local mode, not current behavior.

You are responsible for ensuring your use of any model complies with the applicable license and terms.

---

## 5. API Costs

DukOS does not control, cap, or limit your Anthropic API spend. Running many agents with Opus-class models can cost significant money. Always:

- Set a billing limit in your [Anthropic Console](https://console.anthropic.com)
- Review the `COST.md` estimates before your first run
- Start with Haiku or local models while testing

The maintainers are not responsible for unexpected API bills.

---

## 6. License

DukOS is licensed under the **MIT License**. See `LICENSE` for full text.

In short: free to use, modify, and distribute. No warranty. No liability.

---

*This is a draft document. Legal review required before public release.*
