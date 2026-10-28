-- Network/filesystem adapters are injected so failures can be tested off-game.
local M={revision=240102,version='PC 1.3 R24 / Update 2',repo='saradaken/ThaiChatBridge'}
M.paths={'lib/thaichat/update_core.lua','lib/thaichat/update_runtime.lua','lib/thaichat/carrier_bubble.lua','lib/thaichat/live_auto.lua','lib/thaichat/wide_dictionary.lua','lib/thaichat/wide_dictionary_data.lua','resource/thaichat-codec-ui.js','resource/thaichat-control.css','ThaiChatClaudeProbe.lua'}
local allowed={};for _,p in ipairs(M.paths)do allowed[p]=true end
local function integer(n)return type(n)=='number' and n==math.floor(n)end
function M.validate(doc)
    if type(doc)~='table' or doc.schema~=1 or doc.product~='ThaiChatBridge' or doc.platform~='pc' then return nil,'Invalid manifest identity' end
    if not integer(doc.revision) or doc.revision<1 or doc.revision>2147483647 or type(doc.version)~='string' or #doc.version>80 then return nil,'Invalid version' end
    if doc.requires_asi~='1.3 R24' then return nil,'This update requires a different ASI; install it separately' end
    if type(doc.commit)~='string' or #doc.commit~=40 or doc.commit:find('[^a-f0-9]') then return nil,'Expected immutable commit SHA' end
    if type(doc.notes)~='string' or #doc.notes>2000 or type(doc.files)~='table' or #doc.files<1 or #doc.files>#M.paths then return nil,'Invalid file list' end
    local seen,total={},0
    for k,f in pairs(doc.files)do
        if not integer(k) or k<1 or k>#doc.files or type(f)~='table' or not allowed[f.path] or seen[f.path] then return nil,'Unexpected or duplicate update path' end
        if not integer(f.size) or f.size<1 or f.size>2097152 or type(f.sha256)~='string' or #f.sha256~=64 or f.sha256:find('[^a-f0-9]') then return nil,'Invalid file size or SHA256' end
        seen[f.path]=true;total=total+f.size
    end
    if total>8388608 then return nil,'Update too large' end
    return doc
end
function M.new(io)
    local self={phase='idle',message='Ready to check GitHub',current=M.version,revision=M.revision,busy=false,progress=0}
    local installed=io.load('installed')
    if installed and integer(installed.revision) and type(installed.version)=='string' then self.revision=installed.revision;self.current=installed.version end
    local function status(phase,message)self.phase=phase;self.message=message end
    local function fail(message)self.busy=false;status('error',tostring(message))end
    local function restore(backup)
        if type(backup)~='table' or type(backup.name)~='string' or not backup.name:match('^ThaiChatBridge_%d%d%d%d%d%d%d%d%d%d%.zip$') or type(backup.sha256)~='string' then return nil,'Invalid rollback record' end
        local bytes=io.read_backup(backup.name)
        if not bytes or io.sha(bytes)~=backup.sha256 then return nil,'Backup verification failed' end
        local entries,err=io.unzip(bytes);if not entries then return nil,err end
        local meta=entries['__metadata.json'] and io.decode(entries['__metadata.json'])
        if not meta or type(meta.files)~='table' then return nil,'Missing rollback metadata' end
        local seen={}
        for _,f in ipairs(meta.files)do
            if type(f)~='table' or not allowed[f.path] or seen[f.path] or type(f.existed)~='boolean' or (f.existed and not entries[f.path])then return nil,'Invalid rollback paths' end
            seen[f.path]=true
        end
        for name in pairs(entries)do if name~='__metadata.json' and not seen[name]then return nil,'Unexpected backup entry' end end
        for _,path in ipairs(M.paths)do
            for _,f in ipairs(meta.files)do if f.path==path then
                local ok,why
                if f.existed then ok,why=io.put(path,entries[path])else ok,why=io.remove(path)end
                if not ok then return nil,why end
            end end
        end
        if not io.save('installed',meta.installed)then return nil,'Could not restore installed version' end
        self.revision=meta.installed and meta.installed.revision or M.revision;self.current=meta.installed and meta.installed.version or M.version
        return true
    end
    local journal=io.load('journal')
    if journal then
        local ok,err=restore(journal)
        if ok then io.save('journal',nil);status('recovered','Recovered interrupted update')else self.blocked=true;status('error','Recovery required: '..tostring(err))end
    end
    function self:check()
        if self.busy or self.blocked then return end
        if io.asi_version~='1.3 R24'then fail('Updater requires ThaiChatBridge PC ASI R24');return end
        self.busy=true;self.manifest=nil;self.progress=0;status('checking','Checking GitHub')
        io.fetch('https://raw.githubusercontent.com/'..M.repo..'/main/updates/stable.json',65536,function(bytes,err)
            if not bytes then fail(err);return end
            local doc,why=M.validate(io.decode(bytes));if not doc then fail(why);return end
            self.busy=false;self.latest=doc.version;self.notes=doc.notes
            if doc.revision>self.revision then self.manifest=doc;status('available','Update available')else status('current','Already up to date')end
        end)
    end
    local function apply(doc,files)
        local entries,meta={},{files={},installed=io.load('installed')}
        for _,path in ipairs(M.paths)do if files[path]then
            local old=io.read(path);meta.files[#meta.files+1]={path=path,existed=old~=nil};if old then entries[path]=old end
        end end
        entries['__metadata.json']=io.encode(meta)
        local archive=io.zip(entries);local name,why=io.backup(archive)
        if not name then fail('Backup failed: '..tostring(why));return end
        local record={name=name,sha256=io.sha(archive)}
        if not io.save('journal',record)then fail('Could not create recovery journal');return end
        local ok,err=true
        -- Main script is last, after all dependencies and UI files are in place.
        for _,path in ipairs(M.paths)do if files[path]then ok,err=io.put(path,files[path]);if not ok then break end end end
        if ok then ok=io.save('installed',{revision=doc.revision,version=doc.version})end
        if not ok then
            local recovered,recoveryError=restore(record)
            if recovered then io.save('journal',nil);fail('Install failed; previous files restored: '..tostring(err))
            else self.blocked=true;fail('Recovery required: '..tostring(recoveryError))end
            return
        end
        if not io.save('last-backup',record)then self.blocked=true;fail('Recovery record could not be saved');return end
        if not io.save('journal',nil)then self.blocked=true;fail('Recovery journal could not be cleared');return end
        self.revision=doc.revision;self.current=doc.version;self.manifest=nil;self.busy=false;self.reload=true
        status('installed','Update installed; reloading Lua')
    end
    function self:install()
        if self.busy or self.blocked or not self.manifest then return end
        self.busy=true;self.progress=0;status('downloading','Downloading verified update files')
        local doc,files,index=self.manifest,{},0
        local function nextFile()
            index=index+1
            if index>#doc.files then status('installing','Backing up and installing');apply(doc,files);return end
            local f=doc.files[index]
            io.fetch('https://raw.githubusercontent.com/'..M.repo..'/'..doc.commit..'/pc/moonloader/'..f.path,f.size,function(bytes,err)
                if not bytes then fail(err);return end
                if #bytes~=f.size or io.sha(bytes)~=f.sha256 then fail('Size/SHA256 mismatch: '..f.path);return end
                if f.path:sub(-4)=='.lua' and not loadstring(bytes,'@'..f.path)then fail('Invalid Lua syntax: '..f.path);return end
                files[f.path]=bytes;self.progress=math.floor(index/#doc.files*100);nextFile()
            end)
        end
        nextFile()
    end
    function self:rollback()
        if self.busy or self.blocked then return end
        local record=io.load('last-backup');if not record then fail('No previous update backup');return end
        self.busy=true;status('installing','Restoring previous version')
        if not io.save('journal',record)then fail('Could not create rollback journal');return end
        local ok,err=restore(record)
        if not ok then self.blocked=true;fail(err);return end
        if not io.save('journal',nil)then self.blocked=true;fail('Could not clear rollback journal');return end
        io.save('last-backup',nil);self.busy=false;self.reload=true;status('rolled-back','Previous version restored; reloading Lua')
    end
    function self:state()
        return {phase=self.phase,message=self.message,current=self.current,latest=self.latest,notes=self.notes,progress=self.progress,
            busy=self.busy,canInstall=not self.busy and not self.blocked and self.manifest~=nil,
            canCheck=not self.busy and not self.blocked,canRollback=not self.busy and not self.blocked and io.load('last-backup')~=nil}
    end
    return self
end
return M
