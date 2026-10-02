# Yoda LLM for AMP — personal deployment template

Prepared for Ubuntu x86_64 / Ryzen 9 5900X / 30 GB RAM.
Status: JSON and template references checked locally. Not run under AMP or Linux.
This is an AMP-managed process; it does not create or install Docker.

## Install using AMP and your browser
1. Create a public GitHub repository named amp-llm-templates, with branch main.
2. Extract this ZIP. Upload manifest.json, yoda-llm.kvp, yoda-llmconfig.json and yoda-llmupdates.json at the repository root (not inside a folder).
3. Edit manifest.json: replace YOUR_GITHUB_USERNAME in origin and url with your username. Keep the unique id and prefix.
4. In the main AMP management instance, Configuration -> Instance Deployment -> Configuration Repositories, ADD YOUR_GITHUB_USERNAME/amp-llm-templates:main. Keep existing repositories.
5. Click Fetch and refresh the browser. Create an instance for Yoda LLM (llama.cpp CPU).
6. For this initial test, use an ordinary non-Docker instance. The runtime targets Ubuntu; a Debian container may have different shared libraries.
7. Click Update. It downloads a pinned llama.cpp CPU archive, extracts its executable and companion files, creates an API key, and runs --version to detect missing libraries.
8. Open yoda-llm/serverfiles/api-key.txt through the instance File Manager and keep the key for the PHP server. Depending on File Manager root, the visible path may begin at serverfiles/.
9. Start. The first launch downloads Qwen2.5 3B Q4_K_M (~2.1 GB) into the instance cache. Allow the download to complete. Watch the console; do not restart repeatedly.
10. The instance should reach Ready when it logs "server is listening on". First-launch download time and Ready log detection still require live validation.
11. Check http://SERVER_ADDRESS:8089/health from a machine that can reach the binding. A ready server returns {"status":"ok"}.

## Network binding
The default is 127.0.0.1, for PHP on the same host without Docker.
For PHP on another host, set AMP's application IP binding to the host's reachable private IP, or 0.0.0.0 where appropriate. Ensure port 8089 is available and reachable. AMP admin access cannot guarantee the host firewall/router permits it.
If you need access over the public internet, use an existing HTTPS reverse proxy or private tunnel. This template does not install either.
The generated key authenticates inference; PHP sends Authorization: Bearer YOUR_KEY.
Never put that internal inference key into an LSL script. LSL authenticates to your PHP endpoint separately.

## Test request
Use an HTTP client from the PHP host:
POST http://SERVER_ADDRESS:8089/v1/chat/completions
Authorization: Bearer YOUR_KEY
Content-Type: application/json

Use test-request.json as the request body. Model alias is yoda.
The result text is at choices[0].message.content.
No chat history is required. Each rewrite is independent.

## Failure checks
- Template absent: confirm files are at repo root, manifest URLs were edited, Fetch completed, and browser refreshed.
- Update fails downloading: inspect the actual download error. The runtime URL was located in official release links; it was not downloaded in this Windows workspace.
- Update --version fails: a shared library or executable compatibility issue is the likely next thing to inspect. Send the exact console error; do not try sudo through the application console.
- First start fails downloading model: inspect outbound HTTPS/download errors.
- Running but stuck Starting: inspect the listening log and /health. The Ready regex may need adapting to the exact release log.
- Connection refused remotely: verify IP binding, port, and firewall. With localhost binding, remote access is intentionally unavailable.
- Slow rewrites: measure latency first. Try 6, 8, and 12 threads against the same text; RAM capacity alone does not predict generation speed.
- Stop and restart once after a successful request to verify lifecycle management and model cache reuse.
- Update stops at key generation: Ubuntu utilities bash/tar/find/cp/od/tr are required.

## Design
CPU only, 12 threads, 4096 context tokens, one inference slot.
Model stays loaded while the instance runs.
Runtime build pinned to b11338; updates redownload this version. Model revision is not pinned.
Each update keeps an extract.* staging directory for diagnostics; old directories can be removed manually through AMP after successful validation.
API key is generated once and retained on subsequent updates.
PHP and the LSL addon are not included here: this package establishes the managed model server first.
Yoda wording is a probabilistic transformation; test preservation of names, negatives, numbers, URLs and emotes before enabling it for all chat.

References:
https://github.com/CubeCoders/AMP/wiki/Configuring-the-%27Generic%27-AMP-module
https://github.com/ggml-org/llama.cpp/releases/tag/b11338
https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF
