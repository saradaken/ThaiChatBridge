local M={}
function M.new(root,clock,options)
    options=options or {}
    local ffi=require 'ffi'
    local json=require 'dkjson'
    ffi.cdef[[
        unsigned long __stdcall GetFileAttributesA(const char*);
        int __stdcall CreateDirectoryA(const char*,void*);
        int __stdcall MoveFileExA(const char*,const char*,unsigned long);
        unsigned long __stdcall GetLastError(void);
        void* __stdcall GetModuleHandleA(const char*);
        void* __stdcall GetProcAddress(void*,const char*);
        long __stdcall BCryptOpenAlgorithmProvider(void**,const unsigned short*,const unsigned short*,unsigned long);
        long __stdcall BCryptGetProperty(void*,const unsigned short*,unsigned char*,unsigned long,unsigned long*,unsigned long);
        long __stdcall BCryptCreateHash(void*,void**,unsigned char*,unsigned long,const char*,unsigned long,unsigned long);
        long __stdcall BCryptHashData(void*,const char*,unsigned long,unsigned long);
        long __stdcall BCryptFinishHash(void*,unsigned char*,unsigned long,unsigned long);
        long __stdcall BCryptDestroyHash(void*);
        long __stdcall BCryptCloseAlgorithmProvider(void*,unsigned long);
        unsigned long __stdcall RtlComputeCrc32(unsigned long,const char*,int);
    ]]
    local bcrypt,ntdll=ffi.load('bcrypt'),ffi.load('ntdll')
    local function wide(s)local out=ffi.new('unsigned short[?]',#s+1);for i=1,#s do out[i-1]=s:byte(i)end;return out end
    local function sha(data)
        local provider,hash=ffi.new('void*[1]'),ffi.new('void*[1]')
        assert(bcrypt.BCryptOpenAlgorithmProvider(provider,wide('SHA256'),nil,0)==0,'SHA256 provider unavailable')
        local ok,result=pcall(function()
            local n,got=ffi.new('unsigned long[1]'),ffi.new('unsigned long[1]')
            assert(bcrypt.BCryptGetProperty(provider[0],wide('ObjectLength'),ffi.cast('unsigned char*',n),4,got,0)==0,'SHA256 property failed')
            local object=ffi.new('unsigned char[?]',n[0])
            assert(bcrypt.BCryptCreateHash(provider[0],hash,object,n[0],nil,0,0)==0,'SHA256 init failed')
            assert(bcrypt.BCryptHashData(hash[0],data,#data,0)==0,'SHA256 input failed')
            local digest=ffi.new('unsigned char[32]');assert(bcrypt.BCryptFinishHash(hash[0],digest,32,0)==0,'SHA256 finish failed')
            local out={};for i=0,31 do out[#out+1]=string.format('%02x',digest[i])end
            return table.concat(out)
        end)
        if hash[0]~=nil then bcrypt.BCryptDestroyHash(hash[0])end
        bcrypt.BCryptCloseAlgorithmProvider(provider[0],0)
        if not ok then error(result)end;return result
    end
    local function crc(s)return tonumber(ntdll.RtlComputeCrc32(0,s,#s))end
    local function le(n,width)local t={};for i=1,width do t[i]=string.char(n%256);n=math.floor(n/256)end;return table.concat(t)end
    local function number(s,pos,width)local n=0;for i=width-1,0,-1 do local b=s:byte(pos+i);if not b then return nil end;n=n*256+b end;return n end
    local function zip(entries)
        local names,parts,central,offset={},{},{},0;for name in pairs(entries)do names[#names+1]=name end;table.sort(names)
        for _,name in ipairs(names)do
            local data=entries[name];local sum=crc(data)
            local header='PK\003\004'..le(20,2)..le(0,2)..le(0,2)..le(0,2)..le(33,2)..le(sum,4)..le(#data,4)..le(#data,4)..le(#name,2)..le(0,2)..name
            parts[#parts+1]=header..data
            central[#central+1]='PK\001\002'..le(20,2)..le(20,2)..le(0,2)..le(0,2)..le(0,2)..le(33,2)..le(sum,4)..le(#data,4)..le(#data,4)..le(#name,2)..le(0,2)..le(0,2)..le(0,2)..le(0,2)..le(0,4)..le(offset,4)..name
            offset=offset+#header+#data
        end
        local directory=table.concat(central);parts[#parts+1]=directory
        parts[#parts+1]='PK\005\006'..le(0,2)..le(0,2)..le(#names,2)..le(#names,2)..le(#directory,4)..le(offset,4)..le(0,2)
        return table.concat(parts)
    end
    local function unzip(bytes)
        if #bytes>16777216 then return nil,'Backup too large' end
        local entries,pos,count={},1,0
        while bytes:sub(pos,pos+3)=='PK\003\004'do
            local flags,method=number(bytes,pos+6,2),number(bytes,pos+8,2)
            local sum,size,raw=number(bytes,pos+14,4),number(bytes,pos+18,4),number(bytes,pos+22,4)
            local nameLen,extraLen=number(bytes,pos+26,2),number(bytes,pos+28,2)
            if not extraLen or flags~=0 or method~=0 or size~=raw or size>8388608 then return nil,'Unsupported backup format' end
            local name=bytes:sub(pos+30,pos+29+nameLen);local start=pos+30+nameLen+extraLen
            local data=bytes:sub(start,start+size-1)
            if entries[name] or #data~=size or crc(data)~=sum then return nil,'Corrupt backup entry' end
            entries[name]=data;pos=start+size;count=count+1
            if count>20 then return nil,'Too many backup files' end
        end
        if count==0 or bytes:sub(pos,pos+3)~='PK\001\002'then return nil,'Invalid backup directory' end
        return entries
    end
    root=root:gsub('\\','/'):gsub('/$','')
    local cache=root..'/.thaichat-update'
    local function exists(path)return ffi.C.GetFileAttributesA(path)~=0xffffffff end
    local function mkdir(path)
        path=path:gsub('\\','/');local prefix=path:match('^%a:')or''
        for part in path:gsub('^%a:',''):gmatch('[^/]+')do prefix=prefix..'/'..part
            if not exists(prefix) and ffi.C.CreateDirectoryA(prefix,nil)==0 then return nil,'Could not create directory' end
        end
        return true
    end
    local function readAbsolute(path,max)
        local f,err=io.open(path,'rb');if not f then return nil,err end
        local n=f:seek('end');f:seek('set',0)
        if not n or (max and n>max)then f:close();return nil,'Downloaded file exceeds size limit' end
        local data=f:read('*a');f:close();return data
    end
    local function writeAbsolute(path,data)
        local ok,err=mkdir(path:match('^(.*)/[^/]+$'));if not ok then return nil,err end
        local temp=path..'.thupdate.tmp';local f,why=io.open(temp,'wb');if not f then return nil,why end
        local wrote=f:write(data);local flushed=f:flush();local closed=f:close()
        if not wrote or not flushed or not closed then os.remove(temp);return nil,'Could not write file completely' end
        if ffi.C.MoveFileExA(temp,path,9)==0 then os.remove(temp);return nil,'File replacement failed: '..tonumber(ffi.C.GetLastError())end
        return true
    end
    assert(mkdir(cache))
    local settingsBytes=readAbsolute(cache..'/settings.json',4096)
    local settings=settingsBytes and json.decode(settingsBytes)or{}
    local backupDir=options.backup_directory or (settings and settings.backup_directory)or((os.getenv('LOCALAPPDATA')or root:match('^(.*)/[^/]+$'))..'/ThaiChatBridge/backups')
    backupDir=backupDir:gsub('\\','/'):gsub('/$','');assert(backupDir:match('^%a:/') and not backupDir:find('..',1,true),'Invalid backup directory')
    local runtime={sha=sha,zip=zip,unzip=unzip,encode=json.encode,decode=function(s)return json.decode(s)end}
    local module=ffi.C.GetModuleHandleA('ThaiChatBridge.asi')
    if module~=nil then
        local fn=ffi.C.GetProcAddress(module,'ThaiChatBridgeVersion')
        if fn~=nil then local version=ffi.string(ffi.cast('const char* (__cdecl *)(void)',fn)());runtime.asi_version=version:match('^(1%.3 R24)')end
    end
    function runtime.read(path)
        local file=root..'/'..path;local data,err=readAbsolute(file,8388608)
        if not data and exists(file)then error(err)end;return data
    end
    function runtime.put(path,data)return writeAbsolute(root..'/'..path,data)end
    function runtime.remove(path)local file=root..'/'..path;if not exists(file)then return true end;return os.remove(file)end
    function runtime.load(key)
        local file=cache..'/'..key..'.json';local data,err=readAbsolute(file,65536)
        if not data then if exists(file)then error(err)end;return nil end
        local value,_,why=json.decode(data);assert(value,why or'Invalid update state');return value
    end
    function runtime.save(key,value)
        local file=cache..'/'..key..'.json'
        if value==nil then if not exists(file)then return true end;return os.remove(file)end
        return writeAbsolute(file,json.encode(value))
    end
    function runtime.backup(bytes)
        local stamp=os.date('%d%m')..string.format('%02d',(tonumber(os.date('%Y'))+543)%100)..os.date('%H%M')
        local name='ThaiChatBridge_'..stamp..'.zip';local path=backupDir..'/'..name
        if exists(path)then return nil,'Backup name exists; wait until the next minute' end
        local ok,err=writeAbsolute(path,bytes);if not ok then return nil,err end
        local verified=readAbsolute(path,16777216);if not verified or sha(verified)~=sha(bytes)then return nil,'Backup verification failed' end
        return name
    end
    function runtime.read_backup(name)return readAbsolute(backupDir..'/'..name,16777216)end
    local job,serial=nil,0
    function runtime.fetch(url,max,done)
        assert(not job,'Download already active');serial=serial+1
        local request={path=cache..'/download-'..os.time()..'-'..serial..'.tmp',done=done,max=max,started=clock()};job=request
        if url:find('/main/updates/stable.json',1,true)then url=url..'?check='..os.time()end
        local ok,err=pcall(downloadUrlToFile,url,request.path,function(_,status,received,total)
            if job~=request then return end
            if (received and received>max)or(total and total>max)then request.error='Download exceeds expected size' end
            if status==6 then request.finished=true elseif status<0 then request.error='Download failed';request.finished=true end
        end)
        if not ok then request.error=tostring(err);request.finished=true end
    end
    function runtime.tick()
        if not job then return end
        local request=job
        if not request.finished and clock()-request.started<30000 then return end
        job=nil
        local data,err
        if not request.finished then err='Download timed out (check repository and connection)'
        elseif request.error then err=request.error
        else data,err=readAbsolute(request.path,request.max)end
        -- A timed-out native download may still own its file; never install it.
        if request.finished then os.remove(request.path)end
        request.done(data,err or'GitHub download failed')
    end
    runtime.backup_directory=backupDir
    return runtime
end
return M
