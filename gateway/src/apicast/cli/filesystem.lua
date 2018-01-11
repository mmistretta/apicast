local pl_path = require('pl.path')
local exists, isdir = pl_path.exists, pl_path.isdir
local pl_path_dir = pl_path.dir
local pl_path_join = pl_path.join
local abspath = pl_path.abspath
local pcall = pcall
local co_yield = coroutine.yield
local co_create = coroutine.create
local co_resume = coroutine.resume

local function ldir(dir)
  local ok, iter, state = pcall(pl_path_dir, dir)

  if ok then
    return iter, state
  else
    return nil, iter
  end
end

local function wrap_iter(f)
  local co = co_create(f)

  return function(...)
    local ok, ret = co_resume(co, ...)

    if ok then
      return ret
    else
      return nil, ret
    end
  end
end

return function ( d )
  if not d then return nil end

  local function yieldtree( dir )
    for entry in ldir( dir ) do
      if entry ~= '.' and entry ~= '..' then
        entry = pl_path_join(dir, entry)

        if exists(entry) then  -- Just in case a symlink is broken.
          local is_dir = isdir(entry)
          co_yield( entry, is_dir )
          if is_dir then
            yieldtree( entry )
          end
        end
      end
    end
  end

  return wrap_iter(function() yieldtree( abspath(d) ) end)
end
