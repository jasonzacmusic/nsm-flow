# Speech models, AI, and licenses

NSM Flow's application code is MIT licensed. This covers NSM additions and
retained Handy code. It does not change the licenses of model weights, dependencies,
OS components or an optional external service.

Speech recognition uses downloaded models locally. Vocabulary hints/corrections
and music formatting are application rules; they do not retrain those models.
Optional LLM formatting is a separate step. A local model can be used through a
local OpenAI-compatible server, while a cloud provider sends text off-device and
may charge. “Free app” does not mean every third-party API is free or open source.

## Choosing a model

Use a multilingual model for Indian languages. English-only models can recognize
Indian English speech, but cannot produce general Hindi or Tamil transcription.
Model accuracy depends on language, accent, audio and hardware. The bundled
catalog's scores and language lists come from upstream metadata; NSM has not
verified every entry or reproduced every claimed benchmark.

[OpenAI Whisper](https://github.com/openai/whisper) describes multilingual
recognition and releases its code/weights under MIT. The
[Handy Whisper GGUF conversion card](https://huggingface.co/handy-computer/whisper-small-gguf)
declares Apache-2.0. Consult the exact artifact's conversion card and original
license together when redistributing it; the catalog field is not a legal verdict.

NVIDIA Parakeet models use model-specific licenses. For example,
[Parakeet TDT v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) publishes
CC-BY-4.0 terms. Attribution requirements apply separately from the app's MIT
notice. The catalog also includes `cc-by-nc-4.0` and `other` entries. Do not
assume these allow commercial use or unrestricted redistribution. Look up the
full license before choosing them for school, client or business work.

Models are downloaded on request rather than included in the installer. The
bundled Silero VAD resource comes from the
[Silero VAD project](https://github.com/snakers4/silero-vad), which uses MIT.

## Catalog inventory

This table records the **bundled catalog snapshot**, generated 21 July 2026.
Links point to upstream model cards, whose current terms must be checked before
use or redistribution. A model absent from this table may still be available via
custom/local discovery. `other` means review required, not permission granted.

| Catalog model                                                                                                          | Declared license | Base model                                                                                                            |
| ---------------------------------------------------------------------------------------------------------------------- | ---------------- | --------------------------------------------------------------------------------------------------------------------- |
| [Parakeet Unified EN 0.6B](https://huggingface.co/handy-computer/parakeet-unified-en-0.6b-gguf)                        | `cc-by-4.0`      | [nvidia/parakeet-unified-en-0.6b](https://huggingface.co/nvidia/parakeet-unified-en-0.6b)                             |
| [Nemotron Streaming 3.5](https://huggingface.co/handy-computer/nemotron-3.5-asr-streaming-0.6b-gguf)                   | `other`          | [nvidia/nemotron-3.5-asr-streaming-0.6b](https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b)               |
| [Canary 180M Flash](https://huggingface.co/handy-computer/canary-180m-flash-gguf)                                      | `cc-by-4.0`      | [nvidia/canary-180m-flash](https://huggingface.co/nvidia/canary-180m-flash)                                           |
| [Cohere Transcribe](https://huggingface.co/handy-computer/cohere-transcribe-03-2026-gguf)                              | `apache-2.0`     | [CohereLabs/cohere-transcribe-03-2026](https://huggingface.co/CohereLabs/cohere-transcribe-03-2026)                   |
| [Whisper Medium](https://huggingface.co/handy-computer/whisper-medium-gguf)                                            | `apache-2.0`     | [openai/whisper-medium](https://huggingface.co/openai/whisper-medium)                                                 |
| [Voxtral Mini 4B Realtime](https://huggingface.co/handy-computer/Voxtral-Mini-4B-Realtime-2602-gguf)                   | `apache-2.0`     | [mistralai/Voxtral-Mini-4B-Realtime-2602](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602)             |
| [Parakeet TDT 0.6B v3](https://huggingface.co/handy-computer/parakeet-tdt-0.6b-v3-gguf)                                | `cc-by-4.0`      | [nvidia/parakeet-tdt-0.6b-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)                                     |
| [Parakeet TDT 0.6B v2](https://huggingface.co/handy-computer/parakeet-tdt-0.6b-v2-gguf)                                | `cc-by-4.0`      | [nvidia/parakeet-tdt-0.6b-v2](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2)                                     |
| [Qwen3-ASR 0.6B](https://huggingface.co/handy-computer/Qwen3-ASR-0.6B-gguf)                                            | `apache-2.0`     | [Qwen/Qwen3-ASR-0.6B](https://huggingface.co/Qwen/Qwen3-ASR-0.6B)                                                     |
| [Fun-ASR Nano Multilingual](https://huggingface.co/handy-computer/Fun-ASR-MLT-Nano-2512-gguf)                          | `other`          | [FunAudioLLM/Fun-ASR-MLT-Nano-2512](https://huggingface.co/FunAudioLLM/Fun-ASR-MLT-Nano-2512)                         |
| [Canary 1B Flash](https://huggingface.co/handy-computer/canary-1b-flash-gguf)                                          | `cc-by-4.0`      | [nvidia/canary-1b-flash](https://huggingface.co/nvidia/canary-1b-flash)                                               |
| [Canary 1B v2](https://huggingface.co/handy-computer/canary-1b-v2-gguf)                                                | `cc-by-4.0`      | [nvidia/canary-1b-v2](https://huggingface.co/nvidia/canary-1b-v2)                                                     |
| [Canary 1B](https://huggingface.co/handy-computer/canary-1b-gguf)                                                      | `cc-by-nc-4.0`   | [nvidia/canary-1b](https://huggingface.co/nvidia/canary-1b)                                                           |
| [Canary-Qwen 2.5B](https://huggingface.co/handy-computer/canary-qwen-2.5b-gguf)                                        | `cc-by-4.0`      | [nvidia/canary-qwen-2.5b](https://huggingface.co/nvidia/canary-qwen-2.5b)                                             |
| [Cohere Transcribe](https://huggingface.co/handy-computer/cohere-transcribe-arabic-07-2026-gguf)                       | `apache-2.0`     | [CohereLabs/cohere-transcribe-arabic-07-2026](https://huggingface.co/CohereLabs/cohere-transcribe-arabic-07-2026)     |
| [Fun-ASR Nano](https://huggingface.co/handy-computer/Fun-ASR-Nano-2512-gguf)                                           | `other`          | [FunAudioLLM/Fun-ASR-Nano-2512](https://huggingface.co/FunAudioLLM/Fun-ASR-Nano-2512)                                 |
| [GigaAM v3 CTC](https://huggingface.co/handy-computer/gigaam-v3-ctc-gguf)                                              | `mit`            | [ai-sage/GigaAM-v3](https://huggingface.co/ai-sage/GigaAM-v3)                                                         |
| [GigaAM v3 E2E-CTC](https://huggingface.co/handy-computer/gigaam-v3-e2e-ctc-gguf)                                      | `mit`            | [ai-sage/GigaAM-v3](https://huggingface.co/ai-sage/GigaAM-v3)                                                         |
| [GigaAM v3 RNN-T](https://huggingface.co/handy-computer/gigaam-v3-rnnt-gguf)                                           | `mit`            | [ai-sage/GigaAM-v3](https://huggingface.co/ai-sage/GigaAM-v3)                                                         |
| [GigaAM v3 E2E-RNN-T](https://huggingface.co/handy-computer/gigaam-v3-e2e-rnnt-gguf)                                   | `mit`            | [ai-sage/GigaAM-v3](https://huggingface.co/ai-sage/GigaAM-v3)                                                         |
| [Granite Speech 4.1 2B NAR](https://huggingface.co/handy-computer/granite-speech-4.1-2b-nar-gguf)                      | `apache-2.0`     | [ibm-granite/granite-speech-4.1-2b-nar](https://huggingface.co/ibm-granite/granite-speech-4.1-2b-nar)                 |
| [Granite Speech 4.0 1B](https://huggingface.co/handy-computer/granite-4.0-1b-speech-gguf)                              | `apache-2.0`     | [ibm-granite/granite-4.0-1b-speech](https://huggingface.co/ibm-granite/granite-4.0-1b-speech)                         |
| [Granite Speech 4.1 2B](https://huggingface.co/handy-computer/granite-speech-4.1-2b-gguf)                              | `apache-2.0`     | [ibm-granite/granite-speech-4.1-2b](https://huggingface.co/ibm-granite/granite-speech-4.1-2b)                         |
| [Granite Speech 4.1 2B Plus](https://huggingface.co/handy-computer/granite-speech-4.1-2b-plus-gguf)                    | `apache-2.0`     | [ibm-granite/granite-speech-4.1-2b-plus](https://huggingface.co/ibm-granite/granite-speech-4.1-2b-plus)               |
| [MedASR](https://huggingface.co/handy-computer/medasr-gguf)                                                            | `other`          | [google/medasr](https://huggingface.co/google/medasr)                                                                 |
| [Moonshine Streaming Tiny](https://huggingface.co/handy-computer/moonshine-streaming-tiny-gguf)                        | `mit`            | [UsefulSensors/moonshine-streaming-tiny](https://huggingface.co/UsefulSensors/moonshine-streaming-tiny)               |
| [Moonshine Tiny](https://huggingface.co/handy-computer/moonshine-tiny-gguf)                                            | `mit`            | [UsefulSensors/moonshine-tiny](https://huggingface.co/UsefulSensors/moonshine-tiny)                                   |
| [Moonshine Tiny (Arabic)](https://huggingface.co/handy-computer/moonshine-tiny-ar-gguf)                                | `mit`            | [UsefulSensors/moonshine-tiny-ar](https://huggingface.co/UsefulSensors/moonshine-tiny-ar)                             |
| [Moonshine Tiny (Japanese)](https://huggingface.co/handy-computer/moonshine-tiny-ja-gguf)                              | `mit`            | [UsefulSensors/moonshine-tiny-ja](https://huggingface.co/UsefulSensors/moonshine-tiny-ja)                             |
| [Moonshine Tiny (Korean)](https://huggingface.co/handy-computer/moonshine-tiny-ko-gguf)                                | `mit`            | [UsefulSensors/moonshine-tiny-ko](https://huggingface.co/UsefulSensors/moonshine-tiny-ko)                             |
| [Moonshine Tiny (Ukrainian)](https://huggingface.co/handy-computer/moonshine-tiny-uk-gguf)                             | `mit`            | [UsefulSensors/moonshine-tiny-uk](https://huggingface.co/UsefulSensors/moonshine-tiny-uk)                             |
| [Moonshine Tiny (Vietnamese)](https://huggingface.co/handy-computer/moonshine-tiny-vi-gguf)                            | `mit`            | [UsefulSensors/moonshine-tiny-vi](https://huggingface.co/UsefulSensors/moonshine-tiny-vi)                             |
| [Moonshine Tiny (Chinese)](https://huggingface.co/handy-computer/moonshine-tiny-zh-gguf)                               | `mit`            | [UsefulSensors/moonshine-tiny-zh](https://huggingface.co/UsefulSensors/moonshine-tiny-zh)                             |
| [Moonshine Base](https://huggingface.co/handy-computer/moonshine-base-gguf)                                            | `mit`            | [UsefulSensors/moonshine-base](https://huggingface.co/UsefulSensors/moonshine-base)                                   |
| [Moonshine Base (Arabic)](https://huggingface.co/handy-computer/moonshine-base-ar-gguf)                                | `mit`            | [UsefulSensors/moonshine-base-ar](https://huggingface.co/UsefulSensors/moonshine-base-ar)                             |
| [Moonshine Base (Japanese)](https://huggingface.co/handy-computer/moonshine-base-ja-gguf)                              | `mit`            | [UsefulSensors/moonshine-base-ja](https://huggingface.co/UsefulSensors/moonshine-base-ja)                             |
| [Moonshine Base (Korean)](https://huggingface.co/handy-computer/moonshine-base-ko-gguf)                                | `mit`            | [UsefulSensors/moonshine-base-ko](https://huggingface.co/UsefulSensors/moonshine-base-ko)                             |
| [Moonshine Base (Ukrainian)](https://huggingface.co/handy-computer/moonshine-base-uk-gguf)                             | `mit`            | [UsefulSensors/moonshine-base-uk](https://huggingface.co/UsefulSensors/moonshine-base-uk)                             |
| [Moonshine Base (Vietnamese)](https://huggingface.co/handy-computer/moonshine-base-vi-gguf)                            | `mit`            | [UsefulSensors/moonshine-base-vi](https://huggingface.co/UsefulSensors/moonshine-base-vi)                             |
| [Moonshine Base (Chinese)](https://huggingface.co/handy-computer/moonshine-base-zh-gguf)                               | `mit`            | [UsefulSensors/moonshine-base-zh](https://huggingface.co/UsefulSensors/moonshine-base-zh)                             |
| [Moonshine Streaming Small](https://huggingface.co/handy-computer/moonshine-streaming-small-gguf)                      | `mit`            | [UsefulSensors/moonshine-streaming-small](https://huggingface.co/UsefulSensors/moonshine-streaming-small)             |
| [Moonshine Streaming Medium](https://huggingface.co/handy-computer/moonshine-streaming-medium-gguf)                    | `mit`            | [UsefulSensors/moonshine-streaming-medium](https://huggingface.co/UsefulSensors/moonshine-streaming-medium)           |
| [Nemotron Speech Streaming EN](https://huggingface.co/handy-computer/nemotron-speech-streaming-en-0.6b-gguf)           | `other`          | [nvidia/nemotron-speech-streaming-en-0.6b](https://huggingface.co/nvidia/nemotron-speech-streaming-en-0.6b)           |
| [Parakeet TDT-CTC 110M](https://huggingface.co/handy-computer/parakeet-tdt_ctc-110m-gguf)                              | `cc-by-4.0`      | [nvidia/parakeet-tdt_ctc-110m](https://huggingface.co/nvidia/parakeet-tdt_ctc-110m)                                   |
| [Multitalker Parakeet Streaming EN](https://huggingface.co/handy-computer/multitalker-parakeet-streaming-0.6b-v1-gguf) | `other`          | [nvidia/multitalker-parakeet-streaming-0.6b-v1](https://huggingface.co/nvidia/multitalker-parakeet-streaming-0.6b-v1) |
| [Parakeet CTC 0.6B](https://huggingface.co/handy-computer/parakeet-ctc-0.6b-gguf)                                      | `cc-by-4.0`      | [nvidia/parakeet-ctc-0.6b](https://huggingface.co/nvidia/parakeet-ctc-0.6b)                                           |
| [Parakeet RNN-T 0.6B](https://huggingface.co/handy-computer/parakeet-rnnt-0.6b-gguf)                                   | `cc-by-4.0`      | [nvidia/parakeet-rnnt-0.6b](https://huggingface.co/nvidia/parakeet-rnnt-0.6b)                                         |
| [Parakeet CTC 1.1B](https://huggingface.co/handy-computer/parakeet-ctc-1.1b-gguf)                                      | `cc-by-4.0`      | [nvidia/parakeet-ctc-1.1b](https://huggingface.co/nvidia/parakeet-ctc-1.1b)                                           |
| [Parakeet TDT 1.1B](https://huggingface.co/handy-computer/parakeet-tdt-1.1b-gguf)                                      | `cc-by-4.0`      | [nvidia/parakeet-tdt-1.1b](https://huggingface.co/nvidia/parakeet-tdt-1.1b)                                           |
| [Parakeet RNN-T 1.1B](https://huggingface.co/handy-computer/parakeet-rnnt-1.1b-gguf)                                   | `cc-by-4.0`      | [nvidia/parakeet-rnnt-1.1b](https://huggingface.co/nvidia/parakeet-rnnt-1.1b)                                         |
| [Parakeet TDT-CTC 1.1B](https://huggingface.co/handy-computer/parakeet-tdt_ctc-1.1b-gguf)                              | `cc-by-4.0`      | [nvidia/parakeet-tdt_ctc-1.1b](https://huggingface.co/nvidia/parakeet-tdt_ctc-1.1b)                                   |
| [Qwen3-ASR 1.7B](https://huggingface.co/handy-computer/Qwen3-ASR-1.7B-gguf)                                            | `apache-2.0`     | [Qwen/Qwen3-ASR-1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B)                                                     |
| [MOSS-Transcribe-Diarize 0.9B](https://huggingface.co/handy-computer/moss-transcribe-diarize-gguf)                     | `apache-2.0`     | [OpenMOSS-Team/MOSS-Transcribe-Diarize](https://huggingface.co/OpenMOSS-Team/MOSS-Transcribe-Diarize)                 |
| [SenseVoice Small](https://huggingface.co/handy-computer/SenseVoiceSmall-gguf)                                         | `other`          | [FunAudioLLM/SenseVoiceSmall](https://huggingface.co/FunAudioLLM/SenseVoiceSmall)                                     |
| [Voxtral Mini 3B](https://huggingface.co/handy-computer/Voxtral-Mini-3B-2507-gguf)                                     | `apache-2.0`     | [mistralai/Voxtral-Mini-3B-2507](https://huggingface.co/mistralai/Voxtral-Mini-3B-2507)                               |
| [Voxtral Small 24B](https://huggingface.co/handy-computer/Voxtral-Small-24B-2507-gguf)                                 | `apache-2.0`     | [mistralai/Voxtral-Small-24B-2507](https://huggingface.co/mistralai/Voxtral-Small-24B-2507)                           |
| [Whisper Tiny](https://huggingface.co/handy-computer/whisper-tiny-gguf)                                                | `apache-2.0`     | [openai/whisper-tiny](https://huggingface.co/openai/whisper-tiny)                                                     |
| [Whisper Tiny (English)](https://huggingface.co/handy-computer/whisper-tiny.en-gguf)                                   | `apache-2.0`     | [openai/whisper-tiny.en](https://huggingface.co/openai/whisper-tiny.en)                                               |
| [Whisper Base](https://huggingface.co/handy-computer/whisper-base-gguf)                                                | `apache-2.0`     | [openai/whisper-base](https://huggingface.co/openai/whisper-base)                                                     |
| [Whisper Base (English)](https://huggingface.co/handy-computer/whisper-base.en-gguf)                                   | `apache-2.0`     | [openai/whisper-base.en](https://huggingface.co/openai/whisper-base.en)                                               |
| [Whisper Small (English)](https://huggingface.co/handy-computer/whisper-small.en-gguf)                                 | `apache-2.0`     | [openai/whisper-small.en](https://huggingface.co/openai/whisper-small.en)                                             |
| [Whisper Small](https://huggingface.co/handy-computer/whisper-small-gguf)                                              | `apache-2.0`     | [openai/whisper-small](https://huggingface.co/openai/whisper-small)                                                   |
| [Whisper Medium (English)](https://huggingface.co/handy-computer/whisper-medium.en-gguf)                               | `apache-2.0`     | [openai/whisper-medium.en](https://huggingface.co/openai/whisper-medium.en)                                           |
| [Whisper Large v3 Turbo](https://huggingface.co/handy-computer/whisper-large-v3-turbo-gguf)                            | `apache-2.0`     | [openai/whisper-large-v3-turbo](https://huggingface.co/openai/whisper-large-v3-turbo)                                 |
| [Breeze-ASR-25](https://huggingface.co/handy-computer/Breeze-ASR-25-gguf)                                              | `apache-2.0`     | [MediaTek-Research/Breeze-ASR-25](https://huggingface.co/MediaTek-Research/Breeze-ASR-25)                             |
| [Whisper Large](https://huggingface.co/handy-computer/whisper-large-gguf)                                              | `apache-2.0`     | [openai/whisper-large](https://huggingface.co/openai/whisper-large)                                                   |
| [Whisper Large v2](https://huggingface.co/handy-computer/whisper-large-v2-gguf)                                        | `apache-2.0`     | [openai/whisper-large-v2](https://huggingface.co/openai/whisper-large-v2)                                             |
| [Whisper Large v3](https://huggingface.co/handy-computer/whisper-large-v3-gguf)                                        | `apache-2.0`     | [openai/whisper-large-v3](https://huggingface.co/openai/whisper-large-v3)                                             |

## Dependency and redistribution notes

The Linux build uses a target-only permissive X11/KDE window detector. Its source
and both upstream licenses are retained in `vendor/active-win-pos-rs-linux`.
The prior 0.11 Linux graph pulled in GPL-only Hyprland packages; this build avoids
linking them. Hyprland-specific detection is not claimed. Mac and Windows retain
their accepted 0.11 dependency.

`scripts/collect-licenses.py` traverses the resolved target dependency graph and
collects Cargo/frontend license texts for new Linux packages. This is a packaging
aid, not a complete certification of native sys-crate contents or downloaded
weights. Follow applicable MPL, Apache, Unicode, model attribution and platform
runtime terms. Existing Mac/Windows alpha packages are retained unchanged; a full
in-app model-license display and expanded native-component notices remain future
release work.
