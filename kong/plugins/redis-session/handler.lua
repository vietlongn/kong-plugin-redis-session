-- If you're not sure your plugin is executing, uncomment the line below and restart Kong
-- then it will throw an error which indicates the plugin is being loaded at least.

--assert(ngx.get_phase() == "timer", "The world is coming to an end!")
local redis = require "resty.redis"

-- Grab pluginname from module name
local plugin_name = ({...})[1]:match("^kong%.plugins%.([^%.]+)")

-- load the base plugin object and create a subclass
local plugin = require("kong.plugins.base_plugin"):extend()

-- constructor
function plugin:new()
  plugin.super.new(self, plugin_name)
  
  -- do initialization here, runs in the 'init_by_lua_block', before worker processes are forked

end

---------------------------------------------------------------------------------------------
-- In the code below, just remove the opening brackets; `[[` to enable a specific handler
--
-- The handlers are based on the OpenResty handlers, see the OpenResty docs for details
-- on when exactly they are invoked and what limitations each handler has.
--
-- The call to `.super.xxx(self)` is a call to the base_plugin, which does nothing, except logging
-- that the specific handler was executed.
---------------------------------------------------------------------------------------------


--[[ handles more initialization, but AFTER the worker process has been forked/created.
-- It runs in the 'init_worker_by_lua_block'
function plugin:init_worker()
  plugin.super.access(self)

  -- your custom code here
  
end --]]

--[[ runs in the ssl_certificate_by_lua_block handler
function plugin:certificate(plugin_conf)
  plugin.super.access(self)

  -- your custom code here
  
end --]]

--[[ runs in the 'rewrite_by_lua_block' (from version 0.10.2+)
-- IMPORTANT: during the `rewrite` phase neither the `api` nor the `consumer` will have
-- been identified, hence this handler will only be executed if the plugin is 
-- configured as a global plugin!
function plugin:rewrite(plugin_conf)
  plugin.super.rewrite(self)

  -- your custom code here
  
end --]]

---[[ runs in the 'access_by_lua_block'
function plugin:access(plugin_conf)
  plugin.super.access(self)

  local cookie = require "resty.cookie"

  local ngx_headers = ngx.req.get_headers()
  local ck = cookie:new()
  local session, err = ck:get(plugin_conf.cookie_name)
  ngx.log(ngx.ERR, session)
  if not session then
    ngx.req.set_header("X-Anonymous", true)
    -- ngx.log(ngx.ERR, err)
    return
  end

  local red = redis:new()
  red:set_timeout(plugin_conf.redis_timeout)
  local ok, err = red:connect(plugin_conf.redis_host, plugin_conf.redis_port)
  if not ok then
    ngx.log(ngx.ERR, "failed to connect to Redis: ", err)
    return
  end

  if plugin_conf.redis_password and plugin_conf.redis_password ~= "" then
    local ok, err = red:auth(plugin_conf.redis_password)
    if not ok then
      ngx.log(ngx.ERR, "failed to connect to Redis: ", err)
      return
    end
  end

  local cache_key = session
  if string.len(plugin_conf.redis_session_prefix) > 0 then
    cache_key = plugin_conf.redis_session_prefix .. ":" .. cache_key
  end

  local jwt, err = red:hget(cache_key, plugin_conf.hash_key)
  if err then
    ngx.log(ngx.ERR, "error while fetching redis key: ", err)
    return
  end

  local authorization_header = ngx.header["Authorization"]
  print(authorization_header)
  if not authorization_header then
    ngx.req.set_header("Authorization", "Bearer " .. jwt)
  end
  
end --]]

--[[ runs in the 'header_filter_by_lua_block'
function plugin:header_filter(plugin_conf)
  plugin.super.access(self)

  -- your custom code here, for example;
  ngx.header["Bye-World"] = "this is on the response"

end --]]

--[[ runs in the 'body_filter_by_lua_block'
function plugin:body_filter(plugin_conf)
  plugin.super.access(self)

  -- your custom code here
  
end --]]

--[[ runs in the 'log_by_lua_block'
function plugin:log(plugin_conf)
  plugin.super.access(self)

  -- your custom code here
  
end --]]


-- set the plugin priority, which determines plugin execution order
plugin.PRIORITY = 1000

-- return our plugin object
return plugin
