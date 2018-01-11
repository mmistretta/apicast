local balancer = require('apicast.balancer')
local math = math
local setmetatable = setmetatable

local user_agent = require('apicast.user_agent')

local noop = function() end

local _M = {
  _VERSION = require('apicast.version'),
  _NAME = 'APIcast'
}

local mt = {
  __index = _M
}

--- This is called when APIcast boots the master process.
function _M.new()
  return setmetatable({
    -- So there is no way to use ngx.ctx between request and post_action.
    -- We somehow need to share the instance of the proxy between those.
    -- This table is used to store the proxy object with unique reqeust id key
    -- and removed in the post_action. Because it there is just one instance
    -- of this module in each worker.
    post_action_proxy = {}
  }, mt)
end

function _M.init()
  user_agent.cache()

  math.randomseed(ngx.now())
  -- First calls to math.random after a randomseed tend to be similar; discard them
  for _=1,3 do math.random() end
end

function _M.init_worker()
end

function _M.cleanup()
  -- now abort all the "light threads" running in the current request handler
  ngx.exit(499)
end

function _M:rewrite(context)
  ngx.on_abort(self.cleanup)

  -- load configuration if not configured
  -- that is useful when lua_code_cache is off
  -- because the module is reloaded and has to be configured again

  local p = context.proxy
  p.set_upstream(context.service)
  ngx.ctx.proxy = p
end

function _M:post_action(context)
  local p = context.proxy or ngx.ctx.proxy

  if p then
    return p:post_action()
  else
    ngx.log(ngx.ERR, 'could not find proxy for request')
    return nil, 'no proxy for request'
  end
end

function _M:access(context)
  local p = ngx.ctx.proxy
  ngx.ctx.service = context.service

  local access, handler = p:call(context.service) -- proxy:access() or oauth handler

  local ok, err

  if access then
    ok, err = access()
  elseif handler then
    ok, err = handler()
  end

  return ok, err
end

_M.body_filter = noop
_M.header_filter = noop

_M.balancer = balancer.call

_M.log = noop

return _M
