local ffi = require 'ffi'
local debug = require 'debug'
local base = require "resty.core.base"

-- to get FFI definitions
require 'resty.core.ctx'

local registry = debug.getregistry()
local getfenv = getfenv
local C = ffi.C
local FFI_NO_REQ_CTX = base.FFI_NO_REQ_CTX
local error = error
local tonumber = tonumber

local _M = {

}

local mt = {}

setmetatable(_M, mt)

function _M.ctx_ref()
  local r = getfenv(0).__ngx_req

  if not r then
    return error("no request found")
  end

  local ctx_ref = C.ngx_http_lua_ffi_get_ctx_ref(r)

  if ctx_ref == FFI_NO_REQ_CTX then
    return error("no request ctx found")
  end

  -- TODO: store the extra reference, so the original can't be GCd

  return ctx_ref
end

function _M.ctx(ref)
  local r = getfenv(0).__ngx_req

  if not r then
    return error("no request found")
  end

  local ctx_ref = tonumber(ref)
  if not ctx_ref then
    return
  end

  return registry.ngx_lua_ctx_tables[ctx_ref] or error("no request ctx found")
end

return _M
