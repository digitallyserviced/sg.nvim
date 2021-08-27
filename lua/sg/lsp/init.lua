local log = require "sg.log"
local rpc = require "sg.lsp.rpc"
local handlers = require "sg.lsp.handlers"

-- Weird that they use "/" for requires... I do not like it.
local configs = require "lspconfig/configs"

configs.sg = {
  default_config = {
    cmd = { "nvim", "--headless", "-c", 'lua require("sg.lsp").start()' },
    root_dir = function(fname)
      if not vim.startswith(fname, "sg://") then
        return nil
      end

      log.trace("Successfully connected to:", fname)
      return "/"
    end,
    log_level = vim.lsp.protocol.MessageType.Log,
  },
}

local M = {}

Shutdown = Shutdown or false

M.start = function()
  local ok, msg = pcall(function()
    log.info "[sg lsp] Started"

    while not Shutdown do
      -- header
      local err, data = rpc.read_message()

      if data == nil then
        if err == "eof" then
          return os.exit(1)
        end
        error(err)
      elseif data.method then
        -- request
        if not handlers[data.method] then
          log.info("confused by %t", data)
          err = string.format("%q: Not found/NYI", tostring(data.method))
          log.warn("%s", err)
        else
          local ok
          ok, err = xpcall(function()
            handlers[data.method](data.params, data.id)
          end, debug.traceback)

          if not ok then
            log.warn("%s", tostring(err))
          end
        end
      elseif data.result then
        rpc.finish(data)
      elseif data.error then
        log.info("client error:%s", data.error.message)
      end
    end

    os.exit(0)
  end)

  if not ok then
    log.info("ERROR:", msg)
  end
end

M.setup = function(opts)
  -- TODO: Need to figure out how to ask for the files concurrently.
  -- Otherwise it's gonna take forever to resolve all of them if you've
  -- got a lot of files.
  -- opts.handlers = vim.tbl_deep_extend("force", {
  --   ["textDocument/references"] = function()
  --     print "Yo, references"
  --   end,
  -- }, opts.handlers or {})

  local passed_init = opts.on_init
  opts.on_init = function(client, ...)
    if passed_init then
      passed_init(client, ...)
    end

    local request_sync = client.request_sync
    client.request_sync = function(method, params, timeout_ms, bufnr)
      return request_sync(method, params, timeout_ms, bufnr)
    end

    -- OK, here's the deal chat.
    -- We're going to override the REQUEST and HANDLER for references when we're inside of the sg.nvim client
    -- We want to do this so that we can get all the names of the files that we are going to open. Then we're going
    -- to open them in parallel and wait for them all to complete.
    --
    -- If we don't do this, we request all the results synchronously, and it's quite painful for when you have several
    -- files that these references go between.
    --
    -- Type Kappa in chat if you are following along.
    local request = client.request
    client.request = function(method, params, handler, bufnr)
      if method == "textDocument/references" then
        print "Yo, we requestin this right now"

        local original_handler = handler
        handler = function(err, method, result, ...)
          P(result)

          return nil
        end
      end

      return request(method, params, handler, bufnr)
    end
  end

  require("lspconfig").sg.setup(opts)
end

return M
