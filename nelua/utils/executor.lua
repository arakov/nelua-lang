local plutil = require 'pl.utils'
local tabler = require 'nelua.utils.tabler'
local stringer = require 'nelua.utils.stringer'
local pegger = require 'nelua.utils.pegger'

local executor = {}

-- luacov:disable

-- try to use luaposix exec (faster because we skip shell creation)
local hasposix, posix_pexec = pcall(function()
  local unistd = require 'posix.unistd'
  local wait = require 'posix.sys.wait'.wait
  local plpath = require 'pl.path'
  local poll = require 'posix.poll'

  return function(exe, args, redirect)
    args = args or {}

    -- find the executable
    local exepath = plpath.abspath(exe)
    if exe ~= exepath and not exe:find(plpath.sep, 1, true) then
      exepath = nil
      local envpath = os.getenv('PATH')
      if envpath then
        local paths = stringer.split(envpath, ':')
        for _, pathprefix in ipairs(paths) do
          local trypath = plpath.join(pathprefix, exe)
          if plpath.isfile(trypath) then
            exepath = trypath
            break
          end
        end
      end
    end
    if not exepath then
      return false, 127, "", string.format("%s: command not found\n", exe)
    end
    args[0] = exe

    -- piped fork and exec
    io.stderr:flush()
    io.stdout:flush()
    local outfd, outwfd, errfd, errwfd
    if redirect then
      outfd, outwfd = unistd.pipe()
      errfd, errwfd = unistd.pipe()
    end
    local pid, errmsg = unistd.fork()
    if pid == 0 then
      if redirect then
        unistd.close(outfd) unistd.close(errfd)
        unistd.dup2(outwfd, unistd.STDOUT_FILENO) unistd.dup2(errwfd, unistd.STDERR_FILENO)
      end
      local _, err = unistd.exec(exepath, args)
      -- this is reached only when it fails
      io.stderr:write(err)
      io.stderr:flush()
      unistd._exit(127)
    end
    local ssout = {}
    local sserr = {}
    if redirect then
      unistd.close(outwfd)
      unistd.close(errwfd)
      local fds = {
         [outfd] = {events={IN=true}, ss=ssout},
         [errfd] = {events={IN=true}, ss=sserr}
      }
      repeat
        poll.poll(fds, -1)
        for fd in pairs(fds) do
          if fds[fd].revents.IN then
            local r = unistd.read(fd, 8192)
            if r and #r > 0 then
              table.insert(fds[fd].ss, r)
            end
          end
          if fds[fd].revents.HUP then
            unistd.close(fd)
            fds[fd] = nil
          end
        end
      until not next(fds)
    end
    local _, reason, status = wait(pid)
    local ok = (reason == 'exited') and status == 0
    if redirect then
      unistd.close(outfd) unistd.close(errfd)
      local sout = table.concat(ssout)
      local serr = table.concat(sserr)
      return ok, status, sout, serr
    else
      return ok, status
    end
  end
end)

local function pl_pexec(exe, args, redirect)
  local command = exe
  if args and #args > 0 then
    local strargs = tabler(args):imap(plutil.quote_arg):concat(' '):value()
    command = command .. ' ' .. strargs
  end
  if redirect then
    return plutil.executeex(command)
  else
    return plutil.execute(command)
  end
end

local pexec = hasposix and posix_pexec or pl_pexec

--luacov:enable

local function convertargs(exe, args)
  if not args then
    args = pegger.split_execargs(exe)
    exe = args[1]
    table.remove(args, 1)
  end
  return exe, args
end

-- luacov:disable
function executor.exec(exe, args)
  exe, args = convertargs(exe, args)
  return pexec(exe, args)
end
--luacov:enable

function executor.execex(exe, args)
  exe, args = convertargs(exe, args)
  return pexec(exe, args, true)
end

return executor
