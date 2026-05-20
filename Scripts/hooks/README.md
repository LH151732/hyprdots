# Git hooks

Project-local hooks. Activated by setting `core.hooksPath` once per clone:

```bash
git config core.hooksPath Scripts/hooks
```

After that, every `git commit` in this clone runs these hooks.

## pre-commit

Scans the staged diff for common secret patterns and aborts the commit if
anything matches. Bypass for false positives with `--no-verify`.

Currently detects:

- OpenAI API keys (`sk-...`)
- Anthropic API keys (`sk-ant-...`)
- GitHub PATs (`ghp_`, `gho_`, `github_pat_`)
- AWS access keys (`AKIA...`, `ASIA...`)
- Slack tokens (`xox[abprs]-`)
- Google API keys (`AIza...`)
- Stripe live keys (`sk_live_...`)
- PEM/OpenSSH/PGP private key headers
