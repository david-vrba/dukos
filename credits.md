# Credits

Every external repo, tool, and resource that influenced DukOS is listed here.
No exceptions — this is a matter of principle.

---

## Frameworks & Tools

| Tool | What we use it for | Link |
|---|---|---|
| [Claude Code](https://claude.ai/code) | The runtime all agents run inside | https://claude.ai/code |
| [Anthropic API](https://anthropic.com) | Model provider for all agent shifts | https://anthropic.com |

---

## Inspiration & Prior Art

| Project | What we learned | Link |
|---|---|---|
| [wshobson/agents](https://github.com/wshobson/agents) | Coding-subagent pattern (DukOS takes the business-ops lane they don't cover) | https://github.com/wshobson/agents |
| [ruvnet/ruflo](https://github.com/ruvnet/ruflo) | Sophisticated orchestration swarm for dev tasks (different lane from DukOS) | https://github.com/ruvnet/ruflo |

---

## Built-in Skills

Skills that ship with DukOS use these tools under the hood:

| Skill | Dependencies |
|---|---|
| `/yt-tran` | [yt-dlp](https://github.com/yt-dlp/yt-dlp), [Whisper](https://github.com/openai/whisper), [ffmpeg](https://ffmpeg.org) |
| `/reel` | [yt-dlp](https://github.com/yt-dlp/yt-dlp), [Whisper](https://github.com/openai/whisper), [Playwright](https://playwright.dev), [Firecrawl](https://firecrawl.dev) |
| `/biz-validate` | [Tavily](https://tavily.com), [Firecrawl](https://firecrawl.dev) |

---

*This file grows as DukOS does. If you contributed something and it's not here, open a PR.*
