-- Inline TikZ rendering for fk_markdown.nvim (Kitty graphics protocol).
--
-- Design notes:
-- * Uses its own image-id space (0x770000+) instead of fk_markdown's shared
--   counter. The plugin's latex math renderer deletes and re-transmits its
--   images as the cursor moves; if our extmark highlight still points at an
--   id whose data was deleted, Kitty renders the placeholders as blank. With
--   stable ids the extmark binding never goes stale.
-- * A periodic timer re-transmits active images in place. This heals any
--   external wipe (other plugins sending d=a, terminal clears, etc.) without
--   waiting for a re-parse, which fk_markdown skips when the buffer is
--   unchanged.
-- * Dark-theme friendly: TikZ foreground forced to a light gray so diagrams
--   are visible on dark backgrounds; transparent PNG background.

local uv = vim.uv or vim.loop
local kitty = require("fk_markdown.latex.kitty")

local M = {}
local active = {} ---@type table<string, table>
local errors = {} ---@type table<string, string>
local in_flight = {} ---@type table<string, boolean>
local next_id = 0x770000

local function alloc_id()
  local id = next_id
  next_id = next_id + 1
  if next_id > 0xFFFFF0 then
    next_id = 0x770000
  end
  return id
end

local LOG = vim.fn.stdpath("cache") .. "/fk_markdown/tikz/state.log"
local function log(msg)
  local f = io.open(LOG, "a")
  if f then
    f:write(os.date("%H:%M:%S ") .. msg .. "\n")
    f:close()
  end
end

-- ─── Raw Kitty graphics sender (fixed ids required) ─────────────────────────

local tty ---@type uv_tcp_t|nil

local function get_tty()
  if tty then
    return tty
  end
  tty = uv.new_tty(1, false)
  if not tty then
    vim.notify("[tikz] failed to open stdout TTY for Kitty graphics", vim.log.levels.WARN)
  end
  return tty
end

local function tmux_escape(sequence)
  return "\x1bPtmux;" .. sequence:gsub("\x1b", "\x1b\x1b") .. "\x1b\\"
end

---@param params table<string, string|integer>
---@param payload? string
local function send(params, payload)
  local t = get_tty()
  if not t then
    return
  end
  if params.q == nil then
    params.q = 2
  end
  local parts = {}
  for k, v in pairs(params) do
    parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
  end
  local message
  if payload ~= nil then
    message = string.format("\x1b_G%s;%s\x1b\\", table.concat(parts, ","), vim.base64.encode(payload))
  else
    message = string.format("\x1b_G%s\x1b\\", table.concat(parts, ","))
  end
  local tmux = os.getenv("TMUX")
  if tmux and tmux ~= "" then
    t:write(tmux_escape(message))
  else
    t:write(message)
  end
end

---Transmit (or overwrite) the image for a fixed id and refresh its
---unicode-placeholder binding. Safe to call repeatedly.
---@param path string
---@param id integer
---@param rows integer
---@param cols integer
local function transmit(path, id, rows, cols, quiet)
  local abs = vim.fn.fnamemodify(path, ":p")
  if vim.fn.filereadable(abs) ~= 1 then
    log("SKIP transmit: file missing " .. abs)
    return false
  end
  send({ a = "t", i = id, f = 100, t = "f", C = 1 }, abs)
  send({ a = "p", i = id, U = 1, r = rows, c = cols, C = 1 })
  if not quiet then
    log(string.format("transmitted id=%d rows=%d cols=%d", id, rows, cols))
  end
  return true
end

-- ─── Source extraction and LaTeX wrapping ────────────────────────────────────

local function is_tikz(lang)
  lang = (lang or ""):lower()
  return lang == "tikz" or lang == "tikzpicture"
end

local function extract_code(node)
  local lines = vim.api.nvim_buf_get_lines(node.buf, node.start_row, node.end_row, false)
  if #lines <= 2 then
    return ""
  end
  table.remove(lines, 1)
  if lines[#lines] and (lines[#lines]:match("^%s*```") or lines[#lines]:match("^%s*~~~")) then
    table.remove(lines)
  end
  return table.concat(lines, "\n")
end

local function document(code)
  if code:find("\\documentclass", 1, true) then
    return code
  end
  -- Markdown snippets sometimes include document delimiters but omit a
  -- document class. Strip those delimiters before adding our standalone wrapper.
  code = code:gsub("\\begin%s*{document}", ""):gsub("\\end%s*{document}", "")
  if not code:find("\\begin{tikzpicture}", 1, true) then
    code = "\\begin{tikzpicture}\n" .. code .. "\n\\end{tikzpicture}"
  end
  return table.concat({
    "\\documentclass[tikz,border=2pt]{standalone}",
    "\\usepackage{tikz}",
    "\\usepackage{xcolor}",
    "\\definecolor{TikZForeground}{HTML}{F2F2F2}",
    "\\AtBeginDocument{\\color{TikZForeground}}",
    "\\tikzset{every picture/.style={draw=TikZForeground,text=TikZForeground},every node/.style={text=TikZForeground}}",
    "\\usetikzlibrary{arrows.meta,automata,backgrounds,calc,decorations.pathmorphing,fit,matrix,patterns,positioning,shapes}",
    "\\begin{document}",
    code,
    "\\end{document}",
  }, "\n")
end

-- ─── Compilation ─────────────────────────────────────────────────────────────

---Resolve a tool binary by absolute path. GUI-launched kitty/nvim sessions
---do not inherit TinyTeX's PATH, so `executable()` alone is not enough.
---@param name string
---@return string|nil
local function resolve_bin(name)
  if vim.fn.executable(name) == 1 then
    return name
  end
  local home = vim.fn.expand("~")
  local candidates = {
    home .. "/Library/TinyTeX/bin/universal-darwin/" .. name,
    home .. "/Library/TinyTeX/bin/x86_64-darwin/" .. name,
    home .. "/Library/TinyTeX/bin/aarch64-darwin/" .. name,
    home .. "/.TinyTeX/bin/universal-darwin/" .. name,
    "/opt/homebrew/bin/" .. name,
    "/usr/local/bin/" .. name,
  }
  for _, candidate in ipairs(candidates) do
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  return nil
end

local function compile(code, node_id, callback, pdflatex_bin, pdftocairo_bin)
  local cache = vim.fn.stdpath("cache") .. "/fk_markdown/tikz"
  vim.fn.mkdir(cache, "p")
  local hash = vim.fn.sha256("tikz-dark-v2\n" .. code)
  local png = cache .. "/" .. hash .. ".png"
  if vim.fn.filereadable(png) == 1 and vim.fn.getfsize(png) > 0 then
    -- Defer like the async paths do: fk_markdown must not be re-entered
    -- recursively in the middle of an active parse pass.
    vim.schedule(function()
      callback(png)
    end)
    return
  end
  if in_flight[hash] then
    return
  end
  in_flight[hash] = true

  local dir = cache .. "/build-" .. hash
  vim.fn.mkdir(dir, "p")
  local tex = dir .. "/diagram.tex"
  local file = assert(io.open(tex, "w"))
  file:write(document(code))
  file:close()

  vim.system({ pdflatex_bin, "-interaction=nonstopmode", "-halt-on-error", "-output-directory=" .. dir, tex }, {}, function(latex)
    if latex.code ~= 0 then
      in_flight[hash] = nil
      errors[node_id] = code
      vim.schedule(function()
        vim.notify("TikZ compile failed; run :messages for details\n" .. (latex.stderr or latex.stdout or ""), vim.log.levels.ERROR)
        callback(nil)
      end)
      return
    end
    local png_base = png:gsub("%.png$", "")
    vim.system({ pdftocairo_bin, "-png", "-singlefile", "-transp", "-r", "160", dir .. "/diagram.pdf", png_base }, {}, function(convert)
      in_flight[hash] = nil
      vim.schedule(function()
        if convert.code == 0 and vim.fn.filereadable(png) == 1 and vim.fn.getfsize(png) > 0 then
          errors[node_id] = nil
          callback(png)
        else
          errors[node_id] = code
          vim.notify("TikZ PNG conversion failed: " .. (convert.stderr or ""), vim.log.levels.ERROR)
          callback(nil)
        end
      end)
    end)
  end)
end

-- ─── Extmark helpers ─────────────────────────────────────────────────────────

local function conceal_source(context, marks, node, config, lines)
  local first = vim.api.nvim_buf_get_lines(context.buf, node.start_row, node.start_row + 1, false)[1] or ""
  marks:add(config, false, node.start_row, node.start_col, {
    conceal = "",
    end_row = node.start_row,
    end_col = math.max(#first, node.start_col + 1),
  })
  local compat = require("fk_markdown.lib.compat")
  local last = node.end_row
  if node.end_col == 0 and node.end_row > node.start_row then
    last = node.end_row - 1
  end
  -- nvim swallows virt_lines attached to a fully-concealed line (the fence row),
  -- so anchor BELOW the hidden range instead (probe-verified: V46 visible, V8 gone).
  local anchor = math.min(last + 1, vim.api.nvim_buf_line_count(context.buf) - 1)
  marks:add(config, false, anchor, 0, { virt_lines = lines, virt_lines_above = true })

  for row = node.start_row + 1, last do
    if compat.has_11 then
      marks:add(config, false, row, 0, { conceal_lines = "" })
    else
      local line = vim.api.nvim_buf_get_lines(context.buf, row, row + 1, false)[1] or ""
      marks:add(config, false, row, 0, {
        conceal = "",
        end_row = row,
        end_col = math.max(#line, 1),
        virt_text = { { string.rep(" ", math.max(1, vim.fn.strdisplaywidth(line))), "Normal" } },
        virt_text_pos = "overlay",
        virt_text_hide = true,
      })
    end
  end
end

---@param image table
local function measure(image, win)
  local px_w, px_h = kitty.get_png_dimensions(image.path)
  if px_w == 0 or px_h == 0 then
    return
  end
  local cell_w, cell_h = kitty.get_cell_size()
  local win_ok, width = pcall(vim.fn.winwidth, win)
  if not win_ok or type(width) ~= "number" or width <= 0 then
    width = vim.o.columns
  end
  local max_cols = math.max(20, width - 8)
  local cap = kitty.max_placeholder_dim()
  image.cols = math.min(math.max(1, math.ceil(px_w / cell_w)), cap, max_cols)
  image.rows = math.min(math.max(1, math.ceil(px_h / cell_h)), cap)
end

---Assign a stable id and transmit immediately.
---@param image table
---@return boolean
local function ensure_transmitted(image)
  if image.transmitted then
    return true
  end
  if transmit(image.path, image.id, image.rows, image.cols) then
    image.transmitted = true
    return true
  end
  log("transmit FAILED for id=" .. tostring(image.id))
  return false
end
-- ─── Render entry point ──────────────────────────────────────────────────────
local render_inner

function M.render(context, marks, node, lang)
  -- NEVER let an error here kill fk_markdown's parse pass: everything after
  -- this node in the document would stay unrendered (raw ## / $...$).
  local ok, err = pcall(render_inner, context, marks, node, lang)
  if not ok then
    log("render THREW: " .. tostring(err))
    return false
  end
  return err
end

function render_inner(context, marks, node, lang)
  local pdflatex_bin = resolve_bin("pdflatex")
  local pdftocairo_bin = resolve_bin("pdftocairo")
  if not is_tikz(lang) or not kitty.is_supported() or not pdflatex_bin or not pdftocairo_bin then
    log(string.format("render declined lang=%s kitty=%s pdflatex=%s pdftocairo=%s", tostring(lang), tostring(kitty.is_supported()), tostring(pdflatex_bin), tostring(pdftocairo_bin)))
    return false
  end
  local code = extract_code(node)
  if vim.trim(code) == "" then
    return false
  end
  local node_id = context.buf .. ":" .. node.start_row .. "_" .. node.start_col
  local hash = vim.fn.sha256("tikz-dark-v2\n" .. code)
  if errors[node_id] == code then
    return false
  end

  local image = active[node_id]
  if not image or image.hash ~= hash then
    local old = image
    compile(code, node_id, function(path)
      if not path or not vim.api.nvim_buf_is_valid(context.buf) then
        return
      end
      local fresh = {
        id = alloc_id(),
        path = path,
        buf = context.buf,
        win = context.win,
        hash = hash,
        transmitted = false,
      }
      measure(fresh, context.win)
      if old and old.transmitted then
        pcall(kitty.delete_image, old.id)
      end
      active[node_id] = fresh
      ensure_transmitted(fresh)
      log("rendered node=" .. node_id .. " id=" .. fresh.id .. " rows=" .. fresh.rows .. " cols=" .. fresh.cols)
      local ok_u, err_u = pcall(function()
        require("fk_markdown.core.ui").update(context.buf, context.win, "UserCommand", true)
      end)
      if not ok_u then
        log("ui.update ERROR: " .. tostring(err_u))
      end
    end, pdflatex_bin, pdftocairo_bin)
    return false
  end

  image.win = context.win
  ensure_transmitted(image)
  conceal_source(context, marks, node, context.config.code, kitty.build_virt_lines(image.id, image.rows, image.cols))
  return true
end

-- ─── Self-healing retransmit loop ────────────────────────────────────────────

pcall(function()
  local timer = uv.new_timer()
  timer:start(2000, 2000, vim.schedule_wrap(function()
    for _, image in pairs(active) do
      if image.transmitted and image.path and vim.api.nvim_buf_is_valid(image.buf) then
        -- Overwrite image data with the same id: placeholders bound to this
        -- id recover even if something else wiped Kitty's graphics state.
        -- Overwrite image data with the same id: placeholders bound to this
        -- id recover even if something else wiped Kitty's graphics state.
        pcall(transmit, image.path, image.id, image.rows, image.cols, true)
      end
    end
  end))
  log("self-heal timer started")


  -- Startup race guard: the first render pass during session restore can die
  -- silently (buffer still settling), and fk_markdown then skips re-parsing
  -- the unchanged buffer forever. Nudge one forced update once the dust
  -- settles if a tikz fence exists but never rendered.
  local boot_group = vim.api.nvim_create_augroup("TikzMarkdownBoot", { clear = false })
  vim.api.nvim_create_autocmd({ "VimEnter", "BufWinEnter" }, {
    group = boot_group,
    callback = function(args)
      if not args.buf or vim.bo[args.buf].filetype ~= "markdown" then
        return
      end
      vim.defer_fn(function()
        if not vim.api.nvim_buf_is_valid(args.buf) or vim.fn.bufwinid(args.buf) < 0 then
          return
        end
        local has_tikz = false
        for _, line in ipairs(vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)) do
          if line:match("^%s*```%s*tikz") then
            has_tikz = true
            break
          end
        end
        if not has_tikz then
          return
        end
        for _, image in pairs(active) do
          if image.buf == args.buf and image.transmitted then
            return
          end
        end
        log("boot nudge: forcing update for buf " .. args.buf)
        pcall(function()
          require("fk_markdown.core.ui").update(args.buf, vim.fn.bufwinid(args.buf), "TikzBoot", true)
        end)
      end, 1200)
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      kitty.refresh_cell_size()
      for _, image in pairs(active) do
        if image.path and vim.api.nvim_buf_is_valid(image.buf) then
          local old_cols, old_rows = image.cols, image.rows
          measure(image, image.win)
          if old_cols ~= image.cols or old_rows ~= image.rows then
            transmit(image.path, image.id, image.rows, image.cols)
            pcall(function()
              require("fk_markdown.core.ui").update(image.buf, image.win, "VimResized", true)
            end)
          end
        end
      end
    end,
  })
end)

---Run the render chain step by step against a buffer range and log every
---step. Used to diagnose sessions where render() dies on a silent path.
---@param bufnr integer
---@param start_row integer
---@param end_row integer
function M.debug_probe(bufnr, start_row, end_row)
  log("probe: begin buf=" .. tostring(bufnr) .. " rows=" .. tostring(start_row) .. "." .. tostring(end_row))
  local pdflatex_bin = resolve_bin("pdflatex")
  local pdftocairo_bin = resolve_bin("pdftocairo")
  log("probe: pdflatex=" .. tostring(pdflatex_bin) .. " pdftocairo=" .. tostring(pdftocairo_bin))
  local fake_node = { buf = bufnr, start_row = start_row, end_row = end_row, start_col = 0, end_col = 0 }
  local ok_e, code_or_err = pcall(extract_code, fake_node)
  if not ok_e then
    log("probe: extract_code THREW: " .. tostring(code_or_err))
    return
  end
  local code = code_or_err
  log("probe: extracted " .. #code .. " chars head=" .. code:sub(1, 30):gsub("[%c\"]", " "))
  local hash = vim.fn.sha256("tikz-dark-v2\n" .. code)
  local png = vim.fn.stdpath("cache") .. "/fk_markdown/tikz/" .. hash .. ".png"
  log("probe: png readable=" .. tostring(vim.fn.filereadable(png)) .. " size=" .. tostring(vim.fn.getfsize(png)))
  local image = { id = alloc_id(), path = png, buf = bufnr, win = vim.api.nvim_get_current_win(), hash = hash, transmitted = false }
  local ok_m, err_m = pcall(measure, image, image.win)
  log("probe: measure ok=" .. tostring(ok_m) .. " err=" .. tostring(err_m) .. " rows=" .. tostring(image.rows) .. " cols=" .. tostring(image.cols))
  local ok_t, err_t = pcall(ensure_transmitted, image)
  log("probe: transmit ok=" .. tostring(ok_t) .. " err=" .. tostring(err_t) .. " flag=" .. tostring(image.transmitted))
  active[bufnr .. ":probe"] = image
  log("probe: done")
end

---Find the first tikz fence in the current buffer and run debug_probe on it.
function M.debug_probe_auto()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local start_row, end_row
  for i, line in ipairs(lines) do
    if not start_row and line:match("^%s*```%s*tikz") then
      start_row = i - 1
    elseif start_row and i > start_row + 2 and line:match("^%s*```") then
      end_row = i
      break
    end
  end
  if not start_row or not end_row then
    log("probe-auto: no tikz fence in buffer " .. bufnr)
    vim.notify("[tikz] no tikz fence found in current buffer", vim.log.levels.WARN)
    return
  end
  M.debug_probe(bufnr, start_row, end_row)
  vim.notify("[tikz] probe finished, see cache/fk_markdown/tikz/state.log", vim.log.levels.INFO)
end

function M.debug_state()
  local out = {}
  for k, v in pairs(active) do
    out[#out + 1] = string.format("%s id=%d rows=%d cols=%s transmitted=%s path=%s", k, v.id, v.rows, v.cols, tostring(v.transmitted), v.path)
  end
  return out
end

log("module loaded (v3: stable ids + self-heal)")

return M
