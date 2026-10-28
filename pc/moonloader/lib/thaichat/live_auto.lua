-- Poll-only native handoff. No Lua callback is retained by the ASI.
local M={}
function M.bind()
    local ok,api=pcall(function()
        local ffi=require 'ffi'
        ffi.cdef[[void* __stdcall GetModuleHandleA(const char*); void* __stdcall GetProcAddress(void*,const char*);]]
        local module=ffi.C.GetModuleHandleA('ThaiChatBridge.asi')
        assert(module~=nil,'ASI not loaded')
        local function fn(name,signature)
            local address=ffi.C.GetProcAddress(module,name)
            assert(address~=nil,'R23 API missing: '..name)
            return ffi.cast(signature,address)
        end
        local enabled=fn('ThaiChatCarrierSetEnabled','long (__cdecl *)(long)')
        local cancel=fn('ThaiChatCarrierCancel','long (__cdecl *)(long)')
        local read=fn('ThaiChatCarrierRead','long (__cdecl *)(char*,long,long*)')
        local submit=fn('ThaiChatCarrierSubmit','long (__cdecl *)(long,const char*,long)')
        local buffer,serial=ffi.new('char[32769]'),ffi.new('long[1]')
        return {enable=function(on)return tonumber(enabled(on and 1 or 0))end,
            cancel=function(id)return tonumber(cancel(id or 0))end,
            read=function()local n=tonumber(read(buffer,32769,serial));if n>0 then return tonumber(serial[0]),ffi.string(buffer,n)end end,
            submit=function(id,wire)return tonumber(submit(id,wire,#wire))end}
    end)
    if ok then return api end
    return nil,tostring(api)
end
function M.new(api,build,native,clock,report)
    local self={enabled=false,pending=nil,ms=0,remaining=0,status='Real chat OFF'}
    function self:set(on)
        self:cancel()
        self.enabled=api and api.enable(on)==(on and 1 or 0)and on or false
        self.status=self.enabled and 'Real chat ON' or 'Real chat OFF / requires R23'
    end
    function self:cancel()
        if api then api.cancel(0)end
        self.pending=nil;self.remaining=0
    end
    function self:tick(now,due,active)
        if not self.enabled then return due end
        if active==false then self:cancel();return due end
        local id,text=api.read()
        if not id then self.pending=nil;self.remaining=0;return due end
        if not self.pending or self.pending.id~=id then
            local prefix,body=text:match('^(/%S+%s+)(.*)$')
            prefix,body=prefix or '',body or text
            local command=prefix:match('^/(%S+)')
            if command=='pm'then
                local target,rest=body:match('^(%d+%s+)(.*)$')
                if not target then api.cancel(id);self.status='Invalid /pm target; draft retained';report(self.status);return due end
                prefix,body=prefix..target,rest
            end
            local budget=command=='b'and 115 or command and 99 or 111
            budget=math.min(budget,127-#prefix)
            local started=clock()
            local raw=native.from_utf8(body,0);local encoding=0
            if not raw or native.to_utf8(raw,0)~=body then raw=native.from_utf8(body,1);encoding=1 end
            local wire,n,mode
            if raw then wire,n,mode=build(raw,encoding,budget)end
            self.ms=(clock()-started)*1000
            if not wire then
                api.cancel(id);self.status='Not sent: over budget / no codec; draft retained'
                report(self.status..' ('..tostring(n)..'/'..budget..' bytes)');return due
            end
            self.pending={id=id,wire=prefix..wire,bytes=n,mode=mode}
            self.status=string.format('Ready: %d bytes, codec %d, %.2f ms',n,mode,self.ms)
            report(self.status)
        end
        self.remaining=math.ceil(math.max(0,due-now)/1000)
        if now>=due then
            local result=api.submit(self.pending.id,self.pending.wire)
            self.pending=nil;self.remaining=0
            self.status=result==1 and 'Sent original draft through carrier' or 'Cancelled: draft changed; not sent'
            report(self.status)
            if result==1 then return now+8000 end
        end
        return due
    end
    return self
end
return M
