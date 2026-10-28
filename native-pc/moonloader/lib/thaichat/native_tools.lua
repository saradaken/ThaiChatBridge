-- Optional UI client for the standalone ASI. Contains no codec or dictionary.
local M={}
function M.bind()
    local ffi=require 'ffi'
    ffi.cdef[[void* __stdcall GetModuleHandleA(const char*);void* __stdcall GetProcAddress(void*,const char*);]]
    local module=ffi.C.GetModuleHandleA('ThaiChatBridge.asi')
    assert(module~=nil,'ThaiChatBridge.asi not loaded')
    local function fn(name,signature)
        local address=ffi.C.GetProcAddress(module,name);assert(address~=nil,'Native core API missing: '..name)
        return ffi.cast(signature,address)
    end
    local api={}
    api.abi=fn('ThaiChatCoreAbi','long (__cdecl *)(void)')
    assert(api.abi()==1,'Unsupported native core ABI')
    api.ready=fn('ThaiChatCoreReady','long (__cdecl *)(void)')
    api.running=fn('ThaiChatCoreRunning','long (__cdecl *)(void)')
    api.budget=fn('ThaiChatCoreBudget','long (__cdecl *)(void)')
    local build=fn('ThaiChatCoreBuildEx','long (__cdecl *)(const char*,long,long,long,long,long,char*,long,long*,long*,long*,double*)')
    local decode=fn('ThaiChatCoreDecode','long (__cdecl *)(const char*,long,long,char*,long,char*,long,long*,long*)')
    local phrase=fn('ThaiChatCorePhrase','long (__cdecl *)(long,char*,long)')
    local random=fn('ThaiChatCoreRandom','long (__cdecl *)(const char*,long,long,char*,long)')
    local setOptions=fn('ThaiChatCoreSetOptions','long (__cdecl *)(long,long)')
    local getOptions=fn('ThaiChatCoreGetOptions','long (__cdecl *)(long*,long*)')
    local setEnabled=fn('ThaiChatCoreSetEnabled','long (__cdecl *)(long)')
    local enabled=fn('ThaiChatCoreEnabled','long (__cdecl *)(void)')
    local waitMs=fn('ThaiChatCoreWaitMs','long (__cdecl *)(void)')
    local setWait=fn('ThaiChatCoreSetWaitMs','long (__cdecl *)(long)')
    local cancel=fn('ThaiChatCoreCancel','long (__cdecl *)(void)')
    local status=fn('ThaiChatCoreStatus','long (__cdecl *)(char*,long,double*)')
    local pending=fn('ThaiChatCorePending','long (__cdecl *)(void)')
    local function convert(name)
        local call=fn(name,'int (__cdecl *)(const char*,int,char*,int,int)')
        return function(text,encoding)
            local out=ffi.new('char[16384]');local n=tonumber(call(text,#text,out,16384,encoding))
            if n>=0 and n<16384 then return ffi.string(out,n)end
        end
    end
    api.native={to_utf8=convert('tc_to_utf8'),from_utf8=convert('tc_from_utf8')}
    function api.options()
        local mask,force=ffi.new('long[1]'),ffi.new('long[1]');assert(getOptions(mask,force)==1)
        local options={enabled={},force=tonumber(force[0])<0 and 'auto'or tonumber(force[0])}
        for id=0,9 do options.enabled[id]=math.floor(tonumber(mask[0])/2^id)%2==1 end
        return options
    end
    function api.apply(options)
        local mask=0;for id=0,9 do if options.enabled[id]then mask=mask+2^id end end
        assert(setOptions(mask,options.force=='auto'and -1 or options.force)==1)
    end
    function api.build(raw,encoding,budget)
        local out=ffi.new('char[32769]');local mode,e=ffi.new('long[1]'),ffi.new('long[1]')
        local sizes,ms=ffi.new('long[10]'),ffi.new('double[1]')
        local n=tonumber(build(raw,#raw,encoding,budget,-2,0,out,32769,mode,e,sizes,ms))
        local rows={}
        for id=0,9 do rows[id]={bytes=tonumber(sizes[id])>=0 and tonumber(sizes[id])or math.huge}end
        if n>0 then return ffi.string(out,n),n,tonumber(mode[0]),tonumber(e[0]),rows,tonumber(ms[0])end
        if n<0 then error('Native build failed: '..n)end
        local chosen=tonumber(mode[0]);local required=rows[chosen]and rows[chosen].bytes or math.huge
        return nil,required,chosen>=0 and chosen or nil,tonumber(e[0]),rows,tonumber(ms[0])
    end
    function api.restore(wire)
        local out,raw=ffi.new('char[32769]'),ffi.new('char[4097]');local nraw=ffi.new('long[1]')
        local n=tonumber(decode(wire,#wire,0,out,32769,raw,4097,nraw,nil))
        if n>0 then return ffi.string(out,n),ffi.string(raw,nraw[0])end
    end
    function api.randomPhrase(wire,budget)
        local out=ffi.new('char[32769]');local n=tonumber(random(wire,#wire,budget,out,32769))
        if n>0 then return ffi.string(out,n)end
    end
    function api.phrases()
        local list={};local out=ffi.new('char[1024]')
        for id=0,255 do local n=tonumber(phrase(id,out,1024));if n<0 then break end;list[#list+1]=ffi.string(out,n)end
        return list
    end
    api.setEnabled=function(on)setEnabled(on and 1 or 0)end
    api.cancel=function()cancel()end
    api.waitMs=function()return tonumber(waitMs())end
    api.setWait=function(ms)setWait(math.max(0,math.min(8000,math.floor(ms))))end
    function api.live()
        local out,ms=ffi.new('char[256]'),ffi.new('double[1]');local n=tonumber(status(out,256,ms))
        return enabled()==1,n>=0 and ffi.string(out,n)or'Native status unavailable',tonumber(ms[0]),pending()==1
    end
    return api
end
function M.new(api)
    local options=api.options();local phrases=api.phrases();local computedMs=0
    local run={nextSend=0};local live={};local limits={normal=111,s=99,b=115,me=99}
    function live:set(on)api.setEnabled(on);self.enabled=on end
    function live:cancel()api.cancel();self.pending=nil end
    local function info(text)sampAddChatMessage('[ThaiChatTools] '..text,-1)end
    local function log(text)
        local f=io.open(getWorkingDirectory()..'/ThaiChatTools.log','ab')
        if f then f:write(os.date('%Y-%m-%d %H:%M:%S'),' ',text,'\n');f:close()end
    end
    local function build(raw,encoding,budget)
        api.apply(options)
        local wire,n,mode,e,rows,ms=api.build(raw,encoding,budget);computedMs=ms
        return wire,n,mode,e,rows
    end
    local updaterOk,updater=pcall(function()return require('thaichat.updater_client').bind()end)
    local lab=require('thaichat.codec_lab').new({
        native=api.native,options=options,live=live,liveApi=api,run=run,limits=limits,
        build=build,restore=api.restore,randomPhrase=api.randomPhrase,
        phrases=phrases,phrase=phrases[1],computeMs=function()return computedMs end,
        updater=updaterOk and updater or nil,updateError=not updaterOk and tostring(updater)or nil,
        version='PC 1.3 R25',
        log=log,info=info,hex=function(s)return(s:gsub('.',function(c)return string.format('%02X',c:byte())end))end})
    local self={}
    function self:start()lab:start()end
    function self:close()lab:close()end
    function self:command(command)return lab:command(command)end
    function self:tick()
        local now=getGameTimer()
        limits.normal=tonumber(api.budget())
        run.nextSend=math.max(run.nextSend,now+api.waitMs())
        live.enabled,live.status,live.ms,live.pending=api.live()
        if live.pending then live.pending=true else live.pending=nil end
        local before=run.nextSend;lab:tick()
        if run.nextSend~=before then api.setWait(run.nextSend-now)end
        return math.ceil(math.max(0,run.nextSend-now)/1000),lab:queued()+(live.pending and 1 or 0)
    end
    return self
end
return M
