# Local LLM + Agentic Clients — Hard-Won Lessons

## Hardware: ASUS TUF 16, 8GB VRAM (RTX 4070 Laptop), 64GB RAM

## What works
- **Pi + OmniCoder 2 9B via Ollama**: daily-driver-viable for 
  agentic coding tasks. Fine-tune is specifically trained for
  IDE agents. Pi's prompt efficiency keeps latency tolerable
  despite OmniCoder's partial offload (30/70 CPU/GPU).

## What doesn't work (and why)
- **OpenCode + OmniCoder**: works but slow (~2min for trivial 
  queries). OpenCode's verbose system prompt + tool definitions
  make OmniCoder burn thinking tokens on every turn.
- **Pi + base Qwen 3.5**: Pi bug #2769 (reasoning field not
  handled). Wait for upstream fix or use OmniCoder instead.
- **OpenCode + Qwen 2.5 Coder**: tool-call format mismatch.
  Model emits Qwen-native JSON, OpenCode expects OpenAI tool_calls.
- **Anything + Gemma 4 26B**: too big for 8GB VRAM, CPU-bound.

## Model selection rules for 8GB VRAM agentic work
1. Must have `tools` capability + emit OpenAI-standard tool_calls
2. Prefer fine-tunes explicitly trained for agentic clients
   (OmniCoder, Hermes 3) over general instruct models
3. Thinking mode OK if fine-tuned for productive agent reasoning
4. Base Qwen 3.5 without agentic fine-tune → don't use for tools

## Model ecosystem
- Agentic: omnicoder-oc (OmniCoder 2 9B fine-tune)
- Direct chat / one-shot code: qwen2.5-coder:7b
- General chat: qwen3.5:9b (direct `ollama run`, not via tool clients)
