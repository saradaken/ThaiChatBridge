-- Optional CEF view/transport. No codec, chat events or send queue dependencies.
local M={}
function M.new(deps)
    local json,log,info,Ui=deps.json,deps.log,deps.info,deps.state
    local config=deps.config or {}
    local apiName=config.api or '__thCodecUI'
    local hostId=config.host or 'thaichat-codec-lab'
    local mailboxKey=config.mailbox or 'thaichat_codec_lab'
-- CEF RegWrite2 uses this game-owned root (loader.dll literal). Only our
-- isolated mailbox subkey is read; do not read/change game settings.
local Mailbox=deps.mailbox or rawget(_G,'THCODEC_MAILBOX')
if not Mailbox then
    local ok,result=pcall(function()
        local ffi=require 'ffi'
        ffi.cdef[[
            long __stdcall RegOpenKeyExA(void*,const char*,unsigned long,unsigned long,void**);
            long __stdcall RegQueryValueExA(void*,const char*,unsigned long*,unsigned long*,unsigned char*,unsigned long*);
            long __stdcall RegCloseKey(void*);
        ]]
        local adv=ffi.load('advapi32')
        return {read=function()
            local key=ffi.new('void*[1]')
            local root=ffi.cast('void*',ffi.cast('uintptr_t',0x80000001))
            if adv.RegOpenKeyExA(root,'Software\\ARIZONA GAMES\\NG\\cef\\'..mailboxKey,0,1,key)~=0 then return nil end
            local data=ffi.new('unsigned char[1024]');local n=ffi.new('unsigned long[1]',1024);local kind=ffi.new('unsigned long[1]')
            local code=adv.RegQueryValueExA(key[0],'mailbox',nil,kind,data,n);adv.RegCloseKey(key[0])
            if code~=0 or(kind[0]~=1 and kind[0]~=3)or n[0]<1 or n[0]>1024 then return nil end
            return(ffi.string(data,n[0]):gsub('%z+$',''))
        end}
    end)
    if ok then Mailbox=result else log('CEF_MAILBOX_INIT_ERROR '..tostring(result))end
end
local function cefAscii(js)
    return(js:gsub('[\194-\244][\128-\191]*',function(s)
        local first=s:byte(1)
        local cp=first<(0xe0)and first-0xc0 or first<0xf0 and first-0xe0 or first-0xf0
        for i=2,#s do cp=cp*64+s:byte(i)-128 end
        if cp<65536 then return string.format('\\u%04x',cp)end
        cp=cp-65536
        return string.format('\\u%04x\\u%04x',0xd800+math.floor(cp/1024),0xdc00+cp%1024)
    end))
end
local cefEval
cefEval=function(js)
    js=cefAscii(js)
    if #js>32000 then
        if not cefEval("window.__thCodecChunk='';")then return false end
        for i=1,#js,10000 do
            if not cefEval('window.__thCodecChunk+='..json.encode(js:sub(i,i+9999))..';')then return false end
        end
        return cefEval('(0,eval)(window.__thCodecChunk);delete window.__thCodecChunk;')
    end
    local bs=raknetNewBitStream()
    local ok,err=pcall(function()
        raknetBitStreamWriteInt8(bs,17);raknetBitStreamWriteInt32(bs,0)
        raknetBitStreamWriteInt16(bs,#js);raknetBitStreamWriteInt8(bs,0);raknetBitStreamWriteString(bs,js)
        raknetEmulPacketReceiveBitStream(220,bs)
    end)
    raknetDeleteBitStream(bs)
    if not ok then log('CEF_EVAL_ERROR '..tostring(err))end
    return ok
end

    local self={}
    local lastMailbox,lastPoll,lastRefresh=nil,0,0
    function self:eval(js)return cefEval(js)end
    function self:close()
        Ui.visible=false;Ui.ready=false
        cefEval('window.'..apiName..'&&window.'..apiName..'.destroy();')
        if type(sampToggleCursor)=='function'and not Ui.wasCursor then pcall(sampToggleCursor,false)end
        cefEval("if((document.getElementById('thaichat-codec-lab')||document.getElementById('thaichat-updater'))&&window.cef&&window.cef.ToggleCursor)window.cef.ToggleCursor(0,true,true);")
    end
    function self:open()
        local jsPath=config.js or 'resource/thaichat-codec-ui.js'
        local cssPath=config.css or 'resource/thaichat-control.css'
        local f=io.open(getWorkingDirectory()..'/'..jsPath,'rb')
        if not f then info('Missing '..jsPath);return false end
        local js=f:read('*a');f:close()
        local styleFile=io.open(getWorkingDirectory()..'/'..cssPath,'rb')
        if not styleFile then info('Missing '..cssPath);return false end
        local css=styleFile:read('*a');styleFile:close()
        Ui.wasCursor=type(sampIsCursorActive)=='function'and sampIsCursorActive()or false
        if not cefEval(js)then Ui.visible=false;info('Could not inject CEF UI.');return false end
        local styleJs="(function(){var h=document.getElementById("..json.encode(hostId)..");if(h&&h.shadowRoot){var s=document.createElement('style');s.textContent="..json.encode(css)..";h.shadowRoot.appendChild(s);}})();"
        if not cefEval(styleJs)then self:close();info('Could not inject CEF style.');return false end
        lastMailbox=nil
        if type(sampToggleCursor)=='function'then pcall(sampToggleCursor,true)end
        return true
    end
    function self:tick(control,refresh)
        local now=getGameTimer()
        if Ui.visible and Mailbox and now-lastPoll>=100 then
            lastPoll=now
            local value=Mailbox.read()
            if value and value~=lastMailbox then lastMailbox=value;control(value)end
        end
        if Ui.visible and now-lastRefresh>=1000 then
            if not Ui.ready and now-Ui.openedAt>=4000 then
                info('CEF UI has not acknowledged yet. /'..(config.command or 'thcodecui')..' close can close it.');Ui.openedAt=now+30000
            end
            refresh();lastRefresh=now
        end
    end
    return self
end
return M
