-- Optional CEF bridge; update execution belongs to ThaiChatUpdater.asi.
local M={}
function M.bind()
    local ffi=require 'ffi';local json=require 'dkjson'
    ffi.cdef[[void* __stdcall GetModuleHandleA(const char*);void* __stdcall GetProcAddress(void*,const char*);]]
    local module=ffi.C.GetModuleHandleA('ThaiChatUpdater.asi');assert(module~=nil,'Install ThaiChatUpdater.asi to enable updates')
    local function fn(name,signature)local address=ffi.C.GetProcAddress(module,name);assert(address~=nil,'Updater API missing: '..name);return ffi.cast(signature,address)end
    local abi=fn('ThaiChatUpdaterAbi','long (__cdecl *)(void)');assert(abi()==1,'Unsupported updater ABI')
    local status=fn('ThaiChatUpdaterStatus','long (__cdecl *)(char*,long)')
    local busy=fn('ThaiChatUpdaterBusy','long (__cdecl *)(void)')
    local backup=fn('ThaiChatUpdaterBackupAvailable','long (__cdecl *)(void)')
    local check=fn('ThaiChatUpdaterCheck','long (__cdecl *)(void)')
    local install=fn('ThaiChatUpdaterInstall','long (__cdecl *)(void)')
    local rollback=fn('ThaiChatUpdaterRollback','long (__cdecl *)(void)')
    local cancel=fn('ThaiChatUpdaterCancel','long (__cdecl *)(void)')
    local self={}
    function self:state()
        local out=ffi.new('char[16384]');local n=tonumber(status(out,16384));local value
        if n>0 then value=json.decode(ffi.string(out,n))end
        if type(value)~='table'then return{phase='error',message='Updater status unavailable',canCheck=false,canInstall=false,canRollback=false}end
        local active=busy()==1
        if active then value.busy=true;value.canCheck=false;value.canInstall=false;value.canRollback=false
        elseif value.busy then
            value.phase='error';value.busy=false;value.canCheck=true;value.canInstall=false;value.canRollback=backup()==1
            value.message='Updater helper stopped before completion. Check status or use rollback.'
        end
        return value
    end
    function self:check()return check()==1 end
    function self:install()return install()==1 end
    function self:rollback()return rollback()==1 end
    function self:cancel()return cancel()==1 end
    return self
end
return M
