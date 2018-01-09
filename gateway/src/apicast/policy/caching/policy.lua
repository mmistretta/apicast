local pcall = pcall

local policy = require('apicast.policy')
local _M = policy.new('Caching policy')

local new = _M.new

local function cached_key_var()
  return ngx.var.cached_key
end

local function fetch_cached_key()
  local ok, stored = pcall(cached_key_var)
  return ok and stored
end

local function strict_handler(cache, cached_key, response, ttl)
  -- cached_key is set in post_action and it is in in authorize
  -- so to not write the cache twice lets write it just in authorize
  if response.status == 200 and fetch_cached_key(cached_key) ~= cached_key then
    ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key,
                      ', ttl: ', ttl, ' sub: ')
    cache:set(cached_key, 200, ttl or 0)
  else
    ngx.log(ngx.NOTICE, 'apicast cache delete key: ', cached_key,
                        ' cause status ', response.status)
    cache:delete(cached_key)
  end
end

local function resilient_handler(cache, cached_key, response, ttl)
  local status = response.status

  if status and status < 500 then
    ngx.log(ngx.INFO, 'apicast cache write key: ', cached_key,
                      ' status: ', status, ', ttl: ', ttl)

    cache:set(cached_key, status, ttl or 0)
  end
end

local function init_config(config)
  local res = {}

  if not config.caching_type then
    -- TODO : raise
  elseif config.caching_type == 'resilient' or config.caching_type == 'strict' then
    res.caching_type = config.caching_type
  else
    -- TODO: raise
  end

  return res
end

function _M.new(config)
  local self = new()
  self.config = init_config(config)
  return self
end

function _M:access(context)
  if self.config.caching_type == 'resilient' then
    context.update_cache_func = resilient_handler
  else
    context.update_cache_func = strict_handler
  end
end

return _M
