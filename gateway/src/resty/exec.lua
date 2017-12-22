local ffi = require 'ffi'
local debug = require 'debug'
local base = require "resty.core.base"

-- to get FFI definitions
require 'resty.core.ctx'

local registry = debug.getregistry()
local ref_in_table = base.ref_in_table
local getfenv = getfenv
local C = ffi.C
local FFI_NO_REQ_CTX = base.FFI_NO_REQ_CTX
local FFI_OK = base.FFI_OK
local error = error


local _M = {

}

local mt = {}

setmetatable(_M, mt)

local exec = ngx.exec

function _M.ctx_ref()
  local r = getfenv(0).__ngx_req

  if not r then
    return error("no request found")
  end

  local ctx = ngx.ctx
  local ctx_ref = C.ngx_http_lua_ffi_get_ctx_ref(r)
  if ctx_ref == FFI_NO_REQ_CTX then
    return error("no request ctx found")
  end

  local ctxs = registry.ngx_lua_ctx_tables
  -- TODO: why they are not equal?
  if ctx_ref == ref_in_table(ctxs, ctx) then
    return ctx_ref
  end

  return ref_in_table(ctxs, ctx)
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

  local ctxs = registry.ngx_lua_ctx_tables
  local origin_ngx_ctx = ctxs[ctx_ref]
  ngx.ctx = origin_ngx_ctx

  local FREE_LIST_REF = 0
  ctxs[ctx_ref] = ctxs[FREE_LIST_REF]
  ctxs[FREE_LIST_REF] = ctx_ref
end

return _M
