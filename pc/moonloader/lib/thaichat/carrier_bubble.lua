-- Polling is unnecessary here: the RPC callback precedes the native bubble.
local M={}
function M.bind()
    local ok,result=pcall(function()
        local ffi=require 'ffi'
        ffi.cdef[[void* __stdcall GetModuleHandleA(const char*); void* __stdcall GetProcAddress(void*,const char*);]]
        local module=ffi.C.GetModuleHandleA('ThaiChatBridge.asi')
        assert(module~=nil,'ASI not loaded')
        local address=ffi.C.GetProcAddress(module,'ThaiChatCarrierBubbleRegister')
        assert(address~=nil,'R24 bubble API missing')
        local register=ffi.cast('long (__cdecl *)(long,const char*,long,const char*,long)',address)
        return function(id,wire,text)return tonumber(register(id,wire,#wire,text,#text))==1 end
    end)
    if ok then return result end
    return nil,tostring(result)
end
return M
