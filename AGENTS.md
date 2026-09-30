# AGENTS.md — openproject-docker

Hướng dẫn cho mọi AI agent (Claude Code, Codex, ...) làm việc trong repo này. Luật cá nhân dùng chung
nhiều dự án nằm ở `~/.claude/CLAUDE.md` + `~/.claude/rules/*.md`, không lặp lại ở đây.
Mỗi luật đi kèm **lý do** — đừng "suy luận vòng qua" luật; nếu thấy luật sai, báo user thay vì lờ đi.

## §0. Luật cứng (đọc lướt trước)

| Không bao giờ | Vì sao / xem |
|---|---|
| Commit `.env`, `.env.local`, token `opapi-...`, mật khẩu | Repo public trên GitHub. Secrets chỉ ở `.env*` (gitignored) / password manager. §4 |
| Đụng `lib/`, `openproject/`, `backups/` khi `op-db` đang chạy (copy, xoá, sync) | Là data dir Postgres + asset store đang sống; bản copy giữa chừng là bản hỏng. §4, memory `lessons/deploy/project_docker_data_not_synced` |
| Mở port host cho `op-web` / `op-mcp` trong `docker-compose.yml` | Production chỉ đi qua proxy. Port local để trong `docker-compose.dev.yml`. §2 |
| Sửa CPU/memory limit trong `docker-compose.yml` mà không nói rõ tổng tài nguyên server | Server ít vCore; lịch sử commit có nhiều lần cân lại limit vì stack bị nghẽn. §2 |
| Thêm tool MCP tạo category | API v3 không có endpoint tạo category. memory `lessons/api/project_categories_read_only` |
| Dùng `127.0.0.1` để test web UI local | Login chỉ chạy qua `localhost`. memory `lessons/workflow/project_use_localhost_host` |
| Chạy git trên máy kia khi Syncthing chưa "Up to Date" | `.git` được sync Mac ↔ Windows; chạy song song = conflict refs/objects. §6 |
| Đặt plan ID, phase, mã audit trong code/comment/commit | Chúng mục nát; hãy giải thích hành vi/invariant trực tiếp. §5 |

## §1. Chính sách tool

Thứ tự: **MCP phù hợp → built-in (Read/Glob/Grep) → Bash**. Bash vẫn đúng cho git, docker, pip/pnpm, pytest.

| Việc | ĐỪNG | DÙNG |
|---|---|---|
| Tìm symbol / caller | Grep tên | `serena` `find_symbol`, `find_referencing_symbols` |
| Hiểu kiến trúc / blast radius | đọc tay từng file | `code-review-graph` (`get_architecture_overview_tool`, `get_impact_radius_tool`) |
| Docs thư viện (FastMCP, Rails, Angular, Docker Compose) | trí nhớ, WebSearch | `context7` / `deepwiki` |
| Thao tác dữ liệu OpenProject (WP, time entry, user) | curl API tay | MCP `openproject` (chính server trong repo này) |
| Kiểm tra UI | script puppeteer tự viết | Playwright MCP / chrome-devtools MCP |

Ghi chú vận hành:
- **Serena memory**: đọc `core` rồi `lessons/index` TRƯỚC khi tự suy luận lại hành vi của hệ thống. Học được
  fact mới đã đo → `write_memory` vào `lessons/<topic>/project_<snake_case>` và thêm 1 dòng vào `lessons/index`.
  Memory chỉ chứa fact đã đo, không chứa kế hoạch. Quy ước chi tiết: memory `memory_maintenance`.
- Serena không kết nối được → memories là Markdown thường trong `.serena/memories/`, đọc/ghi trực tiếp.
- Serena và code-review-graph không index file untracked: file mới thì đọc trực tiếp; index rỗng thì build lại
  graph, đừng lùi về grep.
- Kết quả create/update của MCP `openproject` có key `warnings` = field không được áp dụng → luôn báo user.

## §2. Stack (cố định — version nằm ở file sở hữu, không ghi ở đây)

- **Hạ tầng**: Docker Compose. `docker-compose.yml` = production; `docker-compose.dev.yml` = overlay local
  (port host, container `op-dev` để build/test plugin); `docker-compose.control.yml` = job một lần
  (`control/backup`, `control/upgrade`). Tên service tiền tố `op-`.
- **App**: image OpenProject chính thức + plugin, build bằng `Dockerfile.app` (stage 1 build Angular team planner).
  Tag image: `.env` / compose. Nhánh chính `stable/17` bám upstream `opf/openproject-docker-compose`.
- **Plugins**: Rails engine trong `plugins/openproject-<tên>/`, khai báo trong `Gemfile.plugins`.
- **MCP server**: Python FastMCP trong `mcp-server/`, chỉ nói chuyện qua REST API v3, auth per-user
  (header `X-OpenProject-Token`). Chi tiết: `MCP.md`, `mcp-server/README.md`, memory `domains/mcp_server_auth`.
- **Proxy**: Caddy (`proxy/`). Production truy cập qua proxy, không có port host.

## §3. Schema / DRY

- Field work package phụ thuộc project + type: hỏi schema sống (`list_work_package_fields`) thay vì hardcode.
  MCP server kiểm tra ghi theo schema sống; field không hỗ trợ bị bỏ qua kèm `warnings`, không làm hỏng call.
- Locale plugin: mọi key có ở cả `config/locales/en.yml` và `vi.yml`.
- Snippet cấu hình MCP trong plugin `openproject-mcp-ce` dùng hằng `TOKEN_HEADER` / `TOKEN_PLACEHOLDER` của
  controller — sửa một chỗ, đừng copy chuỗi.

## §4. Bảo mật / dữ liệu

- Zero-trust: MCP server hành động bằng token của chính người gọi; không nướng token dùng chung vào image.
- Không commit secrets (§0). `.env.example` chỉ chứa giá trị mẫu.
- Dữ liệu sống (`lib/`, `openproject/`, `backups/`) là riêng từng máy: gitignored và bị Syncthing bỏ qua
  (không `(?d)`). Chuyển dữ liệu giữa máy bằng backup/restore qua `control/backup`, không copy thư mục.

## §5. Chất lượng code & test

- Chạy check hẹp nhất chứng minh được thay đổi: `python -m pytest` trong `mcp-server/`; `pnpm run build` cho
  team planner; `docker compose config -q` cho compose; tải trang thật / gọi MCP thật cho hành vi.
- Mỗi lúc chỉ một lượt test chạy (CPU/RAM máy dev có hạn, stack Docker cũng đang chạy).
- Compose/Dockerfile đổi → stack phải lên được (`docker compose ps` healthy), không chỉ parse được.
- Comment giải thích *vì sao*, không kể lại *cái gì*.

## §6. Git / đồng bộ máy

- Conventional Commits có scope: `fix(compose): ...`, `docs(env): ...`, `feat(mcp): ...`.
- Không có CI/hook trong repo; agent tự chạy check ở §5 trước khi commit. Chỉ commit/push khi user yêu cầu.
- Repo nằm trong thư mục Syncthing `Github/` (Mac `~/Github` ↔ Windows `D:\Github`), luật ở
  `Github/.stignore-shared` (không tạo `.stignore` riêng cho repo). `.git` được sync (trừ lock, index, config,
  logs — riêng từng máy). Bàn giao phải tuần tự: đợi "Up to Date" rồi mới chạy git ở máy kia; sau bàn giao
  kiểm tra `git status` xem có file `*.sync-conflict-*` không.
- `core.filemode`: `false` trên Windows, `true` trên Mac (config không sync).

## §7. UX (plugin)

- Mọi chuỗi hiển thị đi qua i18n (`en` + `vi`), không hardcode.
- Trang admin plugin theo layout/partial chuẩn của OpenProject, không tự chế CSS riêng khi đã có component.

## §8. Đặt tên file

- Plan: `plans/{yyMMdd}-{HHmm}-{slug}/`; report: `plans/reports/{type}-{yyMMdd}-{HHmm}-{slug}.md`.
  `plans/` được gitignore.
- Docs chỉ ở `docs/` hoặc các README sẵn có; không tạo Markdown rải rác ở chỗ khác.
- Memory Serena: `snake_case`, xem §1.

## §9. Chạy agent

- Thay đổi rủi ro (compose production, auth MCP, migration/upgrade): cho ít nhất một reviewer read-only
  xem trước khi commit.
- Không để lại process mồ côi: container/dev server tự bật thì tự tắt khi xong; port bận thì dừng chủ cũ,
  đừng đổi port.
- Đánh giá theo cả pipeline (image build → stack lên → UI/MCP chạy), không chỉ unit test xanh.
