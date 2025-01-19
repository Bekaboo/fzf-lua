local uv = vim.uv or vim.loop
local fzf = require("fzf-lua")
return {
  desc     = "hide interface instead of abort",
  keymap   = {
    builtin = {
      true,
      ["<Esc>"] = "hide",
      ["<M-Esc>"] = "abort"
    }
  },
  defaults = {
    enrich = function(opts)
      if opts._is_fzf_tmux then
        fzf.utils.warn("'hide' profile cannot work with tmux, ignoring.")
        return opts
      end
      -- `execute-silent` actions are bugged with skim
      if fzf.utils.has(opts, "sk") then return opts end
      local histfile = opts.fzf_opts and opts.fzf_opts["--history"]
      opts.actions = opts.actions or {}
      -- While we can use `keymap.builtin.<esc>` (to hide) this is better
      -- as it captures the query when execute-silent action is called as
      -- we add "{q}" as the first field index similar to `--print-query`
      -- opts.actions["esc"] = { fn = fzf.actions.dummy_abort, desc = "hide" }
      opts.actions["esc"] = false
      opts.actions = vim.tbl_map(function(act)
        act = type(act) == "function" and { fn = act } or act
        act = type(act) == "table" and type(act[1]) == "function"
            and { fn = act[1], noclose = true } or act
        assert(type(act) == "table" and type(act.fn) == "function" or not act)
        if type(act) == "table" and
            not act.exec_silent and not act.reload and not act.noclose
        then
          local fn = act.fn
          act.exec_silent = true
          act.desc = act.desc or fzf.config.get_action_helpstr(fn)
          act.fn = function(s, o)
            fzf.hide()
            fn(s, o)
            -- As the process never terminates fzf history is never written
            -- manually append to the fzf history file if needed
            if histfile and type(o.last_query) == "string" and #o.last_query > 0 then
              local fd = uv.fs_open(histfile, "a", -1)
              if fd then
                uv.fs_write(fd, o.last_query .. "\n", nil, function(_)
                  uv.fs_close(fd)
                end)
              end
            end
          end
        end
        return act
      end, opts.actions)
      return opts
    end,
  },
}
