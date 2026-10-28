script_name('ThaiChat CEF Codec Lab V9 R23')
script_description('Experimental R23 live carrier and manual codec tests')
local TEST=rawget(_G,'THCLAUDE_TEST')
local UpdateIO,Updater,UpdateError
if not TEST then
    local ok,result=pcall(function()
        local io=require('thaichat.update_runtime').new(getWorkingDirectory(),function()return getGameTimer()end)
        return {io=io,client=require('thaichat.update_core').new(io)}
    end)
    if ok then UpdateIO,Updater=result.io,result.client else UpdateError=tostring(result)end
end
local BASE=28
local ALPHA={1,2,3,4,5,6,7,8,11,12}
for b=14,31 do ALPHA[#ALPHA+1]=b end
local INDEX={}
for i,b in ipairs(ALPHA)do INDEX[b]=i-1 end
local FREQ={1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,57,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,57,33,1,33,1,1,41,9,9,1,9,1,1,1,1,1,1,1,9,33,17,9,41,1,129,49,25,1,1,9,1,1,65,49,81,1,25,1,33,1,1,17,41,1,121,1,1,17,89,57,25,1,57,1,25,9,25,1,1,1,1,1,1,65,1,1,1,81,1,1,9,97,49,1,9,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
-- number of base-28 digits needed for n bytes (exact, no floating point)
local digitCache = {}
local function digit_count(n)
    if digitCache[n] then return digitCache[n] end
    local num = {}
    for i = 1, n do num[i] = 255 end
    local count = 0
    while true do
        local zero = true
        for j = 1, #num do if num[j] ~= 0 then zero = false break end end
        if zero then break end
        local rem = 0
        for j = 1, #num do
            local cur = rem * 256 + num[j]
            num[j] = math.floor(cur / BASE); rem = cur % BASE
        end
        count = count + 1
    end
    digitCache[n] = count
    return count
end

local function to_digits(bytes, count)
    local num, digits = {}, {}
    for i = 1, #bytes do num[i] = bytes[i] end
    for i = count, 1, -1 do
        local rem = 0
        for j = 1, #num do
            local cur = rem * 256 + num[j]
            num[j] = math.floor(cur / BASE); rem = cur % BASE
        end
        digits[i] = rem
    end
    return digits
end

local function from_digits(digits, n)
    local num = {}
    for i = 1, n do num[i] = 0 end
    for _, d in ipairs(digits) do
        local carry = d
        for j = n, 1, -1 do
            local cur = num[j] * BASE + carry
            num[j] = cur % 256; carry = math.floor(cur / 256)
        end
        if carry > 0 then return nil end
    end
    return num
end

-- two check symbols over the header and digit symbols: a plain sum (catches every single wrong
-- symbol) and a position-weighted sum (catches most swapped neighbours)
local function checks(symbols, count)
    local plain, weighted = 0, 0
    for i = 1, count do
        plain = plain + symbols[i]
        weighted = weighted + symbols[i] * (i % 27 + 1)
    end
    return plain % BASE, weighted % BASE
end


local CUM={[0]=0}
for i,f in ipairs(FREQ)do CUM[i]=CUM[i-1]+f end
local TOTAL=CUM[257]
local HALF,Q=2147483648,1073741824
-- Short-message LZW: fixed 9-bit codes, EOF=256; freeze dictionary at 512.
local function lzw(raw)
    local dictionary={}
    for i=0,255 do dictionary[string.char(i)]=i end
    local nextCode,buffer,bits,out=257,0,0,{}
    local function emit(code)
        buffer=buffer*512+code;bits=bits+9
        while bits>=8 do
            bits=bits-8
            out[#out+1]=string.char(math.floor(buffer/2^bits))
            buffer=buffer%2^bits
        end
    end
    local word=''
    for i=1,#raw do
        local c=raw:sub(i,i);local joined=word..c
        if dictionary[joined]then word=joined
        else
            emit(dictionary[word])
            if nextCode<512 then dictionary[joined]=nextCode;nextCode=nextCode+1 end
            word=c
        end
    end
    if word~=''then emit(dictionary[word])end
    emit(256)
    if bits>0 then out[#out+1]=string.char(buffer*2^(8-bits))end
    return table.concat(out)
end
local function unlzw(raw)
    local dictionary={}
    for i=0,255 do dictionary[i]=string.char(i)end
    local nextCode,pos,buffer,bits,size,out,previous=257,1,0,0,0,{},nil
    while true do
        while bits<9 do
            local b=raw:byte(pos);if not b then return nil end
            pos=pos+1;buffer=buffer*256+b;bits=bits+8
        end
        bits=bits-9
        local code=math.floor(buffer/2^bits);buffer=buffer%2^bits
        if code==256 then
            if pos<=#raw or buffer~=0 then return nil end
            return table.concat(out)
        end
        local entry=dictionary[code]
        if not entry and previous and code==nextCode and nextCode<512 then entry=previous..previous:sub(1,1)end
        if not entry then return nil end
        size=size+#entry;if size>4096 then return nil end
        out[#out+1]=entry
        if previous and nextCode<512 then dictionary[nextCode]=previous..entry:sub(1,1);nextCode=nextCode+1 end
        previous=entry
    end
end
local function arithmetic(raw)
    local lo,hi,pending,bits=0,4294967295,0,{}
    local function emit(bit)
        bits[#bits+1]=bit
        for _=1,pending do bits[#bits+1]=1-bit end
        pending=0
    end
    for i=1,#raw+1 do
        local s=i<=#raw and raw:byte(i)or 256
        local w=hi-lo+1
        hi=lo+math.floor(w*CUM[s+1]/TOTAL)-1
        lo=lo+math.floor(w*CUM[s]/TOTAL)
        while true do
            if hi<HALF then emit(0)
            elseif lo>=HALF then emit(1);lo=lo-HALF;hi=hi-HALF
            elseif lo>=Q and hi<3*Q then pending=pending+1;lo=lo-Q;hi=hi-Q
            else break end
            lo=lo*2;hi=hi*2+1
        end
    end
    pending=pending+1;emit(lo<Q and 0 or 1)
    while #bits%8~=0 do bits[#bits+1]=0 end
    local out={}
    for i=1,#bits,8 do
        local n=0
        for j=0,7 do n=n*2+bits[i+j]end
        out[#out+1]=string.char(n)
    end
    return table.concat(out)
end
local function unarithmetic(raw)
    local pos=0
    local function read()
        local byte=raw:byte(math.floor(pos/8)+1)or 0
        local bit=math.floor(byte/2^(7-pos%8))%2;pos=pos+1
        return bit
    end
    local value=0
    for _=1,32 do value=value*2+read()end
    local lo,hi,out=0,4294967295,{}
    for _=1,4097 do
        local w=hi-lo+1
        local target=math.floor(((value-lo+1)*TOTAL-1)/w)
        local a,b=0,256
        while a<b do
            local mid=math.floor((a+b+1)/2)
            if CUM[mid]<=target then a=mid else b=mid-1 end
        end
        local s=a
        if s==256 then return table.concat(out)end
        out[#out+1]=string.char(s)
        hi=lo+math.floor(w*CUM[s+1]/TOTAL)-1
        lo=lo+math.floor(w*CUM[s]/TOTAL)
        while true do
            if hi<HALF then
            elseif lo>=HALF then lo=lo-HALF;hi=hi-HALF;value=value-HALF
            elseif lo>=Q and hi<3*Q then lo=lo-Q;hi=hi-Q;value=value-Q
            else break end
            lo=lo*2;hi=hi*2+1;value=value*2+read()
        end
    end
    return nil
end
local function encode(raw,version)
    assert(#raw>0 and #raw<=783,'payload size')
    local bytes={raw:byte(1,#raw)}
    local symbols={version or 11,math.floor(#raw/28),#raw%28}
    for _,d in ipairs(to_digits(bytes,digit_count(#raw)))do symbols[#symbols+1]=d end
    local a,b=checks(symbols,#symbols)
    symbols[#symbols+1]=a;symbols[#symbols+1]=b
    local out={}
    for i,d in ipairs(symbols)do out[i]=string.char(ALPHA[d+1])end
    return table.concat(out)
end
local function decode(carrier)
    local s={}
    for i=1,#carrier do s[i]=INDEX[carrier:byte(i)];if s[i]==nil then return nil end end
    if #s<7 or(s[1]~=8 and s[1]~=9 and s[1]~=10 and s[1]~=11 and s[1]~=12 and s[1]~=13 and s[1]~=14)then return nil end
    local n=s[2]*28+s[3]
    if n<1 or n>783 or #s~=5+digit_count(n)then return nil end
    local a,b=checks(s,#s-2)
    if a~=s[#s-1]or b~=s[#s]then return nil end
    local digits={}
    for i=4,#s-2 do digits[#digits+1]=s[i]end
    local bytes=from_digits(digits,n)
    if not bytes then return nil end
    return string.char(unpack(bytes))
end
local PHRASES={
    -- สั้น (สำหรับข้อความไทยขนาดยาว เพดานเหลือจำกัด)
    "Thai",
    "In Thai",
    "u mad bro?",
    "u confused?",
    "cant read this?",
    "u wont get it",
    "typing in Thai lol",
    "secret Thai code lol",
    "Thai mode on lol",
    "alien language haha",
    "ninja language lol",
    "google translate this",

    -- ปานกลาง (กวนๆ ขำๆ ปั่นประสาท)
    "u cant read this haha",
    "wondering what i said?",
    "typing Thai u cant read lol",
    "bro is staring at my chat",
    "bro really trying to read this",
    "just typing in Thai dont mind me",
    "what are you looking at haha",
    "u need a translator bro?",
    "sorry bro you cant read Thai",
    "why are u looking at my chat?",
    "reading this won't help bro haha",
    "it is a secret language bro lol",
    "only cool people can read this",
    "are you confused yet haha?",

    -- ยาว (สำหรับข้อความไทยสั้นๆ บัดเจ็ทเหลือเยอะ ปั่นเต็มคาราเบล)
    "confused what im typing right now haha",
    "bro really thought he could understand this",
    "im just speaking Thai u will never understand",
    "bro is using 100% brain to read this haha",
    "staring at my screen wont help u read this bro",
    "you look confused trying to read my Thai chat lol",
    "i'm gonna speak Thai because you cant understand",
    "why are you staring at my chat so hard bro haha",
    "you really thought google translate would work here lol",
    "sorry my friend this is ancient Thai ninja language",
    "bro is literally scratching his head right now haha",
    "dont look at me look at the road while driving lol"
}
local PHRASE=PHRASES[1]
local lastChosenPhrase=""
local function phraseAt(text,start)
    local first,last
    for _,phrase in ipairs(PHRASES)do
        local a,b=text:find(phrase,start,true)
        if a and(not first or a<first or(a==first and b>last))then first,last=a,b end
    end
    return first,last
end
local function randomPhrase(wire,budget)
    local a,b=phraseAt(wire,1);if a~=1 then return nil end
    local frame=wire:sub(b+1)
    local fitting={}
    for _,phrase in ipairs(PHRASES)do
        if #phrase+#frame<=budget then
            fitting[#fitting+1]=phrase
        end
    end
    if #fitting==0 then return nil end
    if #fitting==1 then
        lastChosenPhrase=fitting[1]
        return fitting[1]..frame
    end

    -- กรองเอาคำที่ไม่ซ้ำกับคำก่อนหน้า (Anti-Repeat)
    local nonRepeated={}
    for _,phrase in ipairs(fitting)do
        if phrase~=lastChosenPhrase then
            nonRepeated[#nonRepeated+1]=phrase
        end
    end
    local pool=#nonRepeated>0 and nonRepeated or fitting

    -- ถ้าบัดเจ็ทเหลือเยอะ ให้สุ่มเลือกจากกลุ่มประโยคที่ยาวกว่าเป็นหลัก
    local maxLen=0
    for _,p in ipairs(pool)do if #p>maxLen then maxLen=#p end end
    local preferred={}
    for _,p in ipairs(pool)do
        if #p>=maxLen-15 then preferred[#preferred+1]=p end
    end
    local finalPool=#preferred>0 and preferred or pool

    local picked=finalPool[math.random(#finalPool)]
    lastChosenPhrase=picked
    return picked..frame
end
-- Keep envelope kinds and bytes; never infer item IDs from translated names.
-- Escape 0: literal NUL; 1/2: th/u8 bytes with a bounded base-128 length.
local EMOJIS = {
    "\240\159\145\169\240\159\143\189\226\128\141\240\159\146\187",
    "\240\159\135\185\240\159\135\173",
    "\049\239\184\143\226\131\163",
    "\239\184\143\226\131\163",
    "\240\159\145\141\240\159\143\189",
    "\240\159\152\128", "\240\159\152\131", "\240\159\152\132", "\240\159\152\129",
    "\240\159\152\134", "\240\159\152\133", "\240\159\152\130", "\240\159\164\163",
    "\240\159\152\138", "\240\159\152\135", "\240\159\153\130", "\240\159\152\137",
    "\240\159\152\141", "\240\159\165\176", "\240\159\152\152", "\240\159\152\139",
    "\240\159\152\155", "\240\159\164\148", "\240\159\152\142", "\240\159\165\179",
    "\240\159\152\143", "\240\159\164\162", "\240\159\152\173", "\240\159\152\161",
    "\240\159\164\175", "\240\159\145\141", "\240\159\145\142", "\240\159\146\147",
    "\226\157\164\239\184\143", "\240\159\148\165", "\240\159\154\151", "\240\159\146\176",
    "\240\159\146\181", "\240\159\146\184", "\240\159\146\179", "\240\159\145\145",
    "\240\159\146\142", "\240\159\148\171", "\240\159\147\161", "\226\154\148\239\184\143",
    "\240\159\155\161\239\184\143", "\240\159\146\163"
}
table.sort(EMOJIS, function(a, b) return #a > #b end)
local EMOJI_MAP = {}
for i, s in ipairs(EMOJIS) do EMOJI_MAP[s] = i - 1 end

local function compressU8(payload)
    local out, pos, n = {}, 1, #payload
    while pos <= n do
        local b1, b2, b3, b4 = payload:byte(pos, pos + 3)
        if b1 == 0xF1 and b2 and b2 >= 0x90 and b2 <= 0x9F and b3 and b4 then
            local cp = (b1 % 8) * 262144 + (b2 % 64) * 4096 + (b3 % 64) * 64 + (b4 % 64)
            local item_id = cp - 0x50000
            out[#out + 1] = '\245'
            local val = item_id
            repeat
                local byte = val % 128; val = math.floor(val / 128)
                out[#out + 1] = string.char(byte + (val > 0 and 128 or 0))
            until val == 0
            pos = pos + 4
        elseif b1 == 0xF1 and b2 and b2 >= 0xA0 and b2 <= 0xAF and b3 and b4 then
            local cp = (b1 % 8) * 262144 + (b2 % 64) * 4096 + (b3 % 64) * 64 + (b4 % 64)
            local slot_id = cp - 0x60000
            out[#out + 1] = '\246'
            local val = slot_id
            repeat
                local byte = val % 128; val = math.floor(val / 128)
                out[#out + 1] = string.char(byte + (val > 0 and 128 or 0))
            until val == 0
            pos = pos + 4
        else
            local matched = false
            for _, s in ipairs(EMOJIS) do
                local len = #s
                if pos + len - 1 <= n and payload:sub(pos, pos + len - 1) == s then
                    local idx = EMOJI_MAP[s]
                    if idx < 256 then
                        out[#out + 1] = '\247' .. string.char(idx)
                    else
                        out[#out + 1] = '\248' .. string.char(math.floor(idx / 256), idx % 256)
                    end
                    pos = pos + len
                    matched = true
                    break
                end
            end
            if not matched then
                local b = payload:byte(pos)
                if b == 0xF5 or b == 0xF6 or b == 0xF7 or b == 0xF8 or b == 0xF9 then
                    out[#out + 1] = '\249' .. string.char(b)
                else
                    out[#out + 1] = string.char(b)
                end
                pos = pos + 1
            end
        end
    end
    return table.concat(out)
end

local function decompressU8(compressed)
    local out, pos, n = {}, 1, #compressed
    while pos <= n do
        local b = compressed:byte(pos)
        pos = pos + 1
        if b == 0xF5 then
            local val, scale = 0, 1
            while pos <= n do
                local byte = compressed:byte(pos); pos = pos + 1
                val = val + (byte % 128) * scale; scale = scale * 128
                if byte < 128 then break end
            end
            local cp = 0x50000 + val
            local b1 = 0xF0 + math.floor(cp / 262144)
            local b2 = 0x80 + math.floor((cp % 262144) / 4096)
            local b3 = 0x80 + math.floor((cp % 4096) / 64)
            local b4 = 0x80 + (cp % 64)
            out[#out + 1] = string.char(b1, b2, b3, b4)
        elseif b == 0xF6 then
            local val, scale = 0, 1
            while pos <= n do
                local byte = compressed:byte(pos); pos = pos + 1
                val = val + (byte % 128) * scale; scale = scale * 128
                if byte < 128 then break end
            end
            local cp = 0x60000 + val
            local b1 = 0xF0 + math.floor(cp / 262144)
            local b2 = 0x80 + math.floor((cp % 262144) / 4096)
            local b3 = 0x80 + math.floor((cp % 4096) / 64)
            local b4 = 0x80 + (cp % 64)
            out[#out + 1] = string.char(b1, b2, b3, b4)
        elseif b == 0xF7 then
            local idx = compressed:byte(pos); pos = pos + 1
            out[#out + 1] = EMOJIS[idx + 1]
        elseif b == 0xF8 then
            local idx1, idx2 = compressed:byte(pos, pos + 1); pos = pos + 2
            local idx = idx1 * 256 + idx2
            out[#out + 1] = EMOJIS[idx + 1]
        elseif b == 0xF9 then
            local literal = compressed:byte(pos); pos = pos + 1
            out[#out + 1] = string.char(literal)
        else
            out[#out + 1] = string.char(b)
        end
    end
    return table.concat(out)
end

local function compact(raw)
    local out,pos={},1
    while pos<=#raw do
        local kind=raw:sub(pos,pos+4)
        local ending=(kind=='[[th:'or kind=='[[u8:')and raw:find(']]',pos+5,true)
        if ending then
            local payload=raw:sub(pos+5,ending-1)
            if kind=='[[u8:' then payload=compressU8(payload) end
            local n=#payload
            out[#out+1]=string.char(0,kind=='[[th:'and 1 or 2)
            repeat
                local byte=n%128;n=math.floor(n/128)
                out[#out+1]=string.char(byte+(n>0 and 128 or 0))
            until n==0
            out[#out+1]=payload;pos=ending+2
        else
            local byte=raw:sub(pos,pos)
            out[#out+1]=byte=='\0'and '\0\0'or byte;pos=pos+1
        end
    end
    return table.concat(out)
end
local function expand(raw)
    local out,pos={},1
    while pos<=#raw do
        local byte=raw:byte(pos);pos=pos+1
        if byte~=0 then out[#out+1]=string.char(byte)
        else
            local kind=raw:byte(pos);pos=pos+1
            if kind==0 then out[#out+1]='\0'
            elseif kind==1 or kind==2 then
                local n,scale,done=0,1,false
                for _=1,2 do
                    local b=raw:byte(pos);if not b then return nil end
                    pos=pos+1;n=n+(b%128)*scale;scale=scale*128
                    if b<128 then done=true;break end
                end
                if not done or n>4096 or pos+n-1>#raw then return nil end
                local payload=raw:sub(pos,pos+n-1)
                if kind==2 then payload=decompressU8(payload) if not payload then return nil end end
                out[#out+1]=(kind==1 and '[[th:'or '[[u8:')..payload..']]'
                pos=pos+n
            else return nil end
        end
    end
    return table.concat(out)
end
local Native=rawget(_G,'THCODEC_NATIVE')
local nativeError
if not TEST then
    local ok,result=pcall(function()
        local ffi=require 'ffi'
        ffi.cdef[[
            int tc_abi(void);
            int tc_usx_encode(const char*,int,char*,int,int);
            int tc_usx_decode(const char*,int,char*,int,int);
            int tc_to_utf8(const char*,int,char*,int,int);
            int tc_from_utf8(const char*,int,char*,int,int);
        ]]
        local dll=ffi.load(getWorkingDirectory()..'/lib/ThaiChatCodec.dll')
        assert(dll.tc_abi()==4,'codec helper ABI mismatch')
        local function call(fn,raw,arg)
            local cap=fn=='tc_usx_decode'and 4096 or 16384
            local out=ffi.new('char[?]',cap)
            local n=dll[fn](raw,#raw,out,cap,arg)
            if n<0 or n>=cap then return nil end
            return ffi.string(out,n)
        end
        return {
            to_utf8=function(raw,e)return call('tc_to_utf8',raw,e)end,
            from_utf8=function(raw,e)return call('tc_from_utf8',raw,e)end,
            usx_encode=function(raw,p)return call('tc_usx_encode',raw,p)end,
            usx_decode=function(raw,p)return call('tc_usx_decode',raw,p)end,
        }
    end)
    if ok then Native=result else nativeError=tostring(result)end
end
local WORDS={"\202\199\209\202\180\213","\164\195\209\186","\199\209\185\185\213\233","\205\194\217\232","\183\213\232\228\203\185","\183\211\205\208\228\195","\228\193\232\224\187\231\185\228\195","\162\205\186\164\216\179","\228\187","\161\197\209\186","\180\233\199\194\161\209\185","\224\183\232\210\228\203\195\232","\181\205\185\185\213\233","\224\180\213\235\194\199","\195\205","\224\190\215\232\205\185","\203\185\232\205\194"}
local function dictionary(raw)
    local out,pos={},1
    while pos<=#raw do
        local best,index=0,nil
        for i,word in ipairs(WORDS)do
            if #word>best and raw:sub(pos,pos+#word-1)==word then best=#word;index=i end
        end
        if best>2 then out[#out+1]=string.char(0,index);pos=pos+best
        else
            local byte=raw:sub(pos,pos);out[#out+1]=byte=='\0'and '\0\0'or byte;pos=pos+1
        end
    end
    return table.concat(out)
end
local function undictionary(raw)
    local out,pos={},1
    while pos<=#raw do
        local byte=raw:sub(pos,pos);pos=pos+1
        if byte=='\0'then
            local index=raw:byte(pos);pos=pos+1
            if not index or(index>0 and not WORDS[index])then return nil end
            out[#out+1]=index==0 and '\0'or WORDS[index]
        else out[#out+1]=byte end
    end
    return table.concat(out)
end
-- Frozen V1 dictionary: changing order requires a NEW codec mode/version.
local THAI_WORDS={"\202\199\209\202\180\213","\164\195\209\186","\164\232\208","\162\205\186\164\216\179","\162\205\226\183\201","\228\193\232\224\187\231\185\228\195","\183\211\205\208\228\195","\205\194\217\232\183\213\232\228\203\185","\199\209\185\185\213\233","\181\205\185\185\213\233","\224\180\213\235\194\199","\224\190\215\232\205\185","\203\185\232\205\194","\228\180\233\228\203\193","\228\193\232\228\180\233","\228\180\233\224\197\194","\227\170\232\228\203\193","\194\209\167\228\167","\205\208\228\195","\183\211\228\193","\224\193\215\232\205\228\203\195\232","\224\183\232\210\228\203\195\232","\168\195\212\167","\224\203\193\215\205\185","\190\195\233\205\193","\192\210\201\210\228\183\194","\192\210\201\210\205\209\167\161\196\201","\195\209\202\224\171\213\194","\162\233\205\164\199\210\193","\228\205\164\205\185","\205\212\226\193\168\212","\225\170\183","\224\197\232\185\224\161\193","\161\197\209\186\186\233\210\185","\195\205\161\232\205\185","\228\187\228\203\185","\161\212\185\162\233\210\199","\225\197\233\199\164\195\209\186","\185\208\164\195\209\186","\185\208\164\208","\224\197\194\164\195\209\186","\224\195\213\194\186\195\233\205\194","\183\180\202\205\186","\190\212\193\190\236","\202\232\167\193\210","\195\209\186\225\197\233\199","\224\168\205\161\209\185","\183\216\161\164\185","\202\186\210\194\180\213","\228\193\232\193\213","\228\193\232\181\233\205\167","\181\233\205\167\161\210\195","\202\210\193\210\195\182","\180\233\199\194\161\209\185","\170\232\199\194\180\233\199\194","\224\162\233\210\227\168","\183\211\167\210\185","\193\210\161\161\199\232\210","\185\233\205\194\161\199\232\210","\161\210","\161\213","\161\217","\162\210","\162\213","\162\217","\164\210","\164\213","\164\217","\167\210","\167\213","\167\217","\168\210","\168\213","\168\217","\170\210","\170\213","\170\217","\180\210","\180\213","\180\217","\181\210","\181\213","\181\217","\183\210","\183\213","\183\217","\185\210","\185\213","\185\217","\186\210","\186\213","\186\217","\187\210","\187\213","\187\217","\190\210","\190\213","\190\217","\193\210","\193\213","\193\217","\194\210","\194\213","\194\217","\195\210","\195\213","\195\217","\197\210","\197\213","\197\217","\199\210","\199\213","\199\217","\202\210","\202\213","\202\217","\203\210","\203\213","\203\217","\205\210","\205\213","\205\217"}
local THAI_WORDS_V2={"\202\199\209\202\180\213","\164\195\209\186","\164\232\208","\162\205\186\164\216\179","\162\205\226\183\201","\228\193\232\224\187\231\185\228\195","\183\211\205\208\228\195","\205\194\217\232\183\213\232\228\203\185","\199\209\185\185\213\233","\181\205\185\185\213\233","\224\180\213\235\194\199","\224\190\215\232\205\185","\203\185\232\205\194","\228\180\233\228\203\193","\228\193\232\228\180\233","\228\180\233\224\197\194","\227\170\232\228\203\193","\194\209\167\228\167","\205\208\228\195","\183\211\228\193","\224\193\215\232\205\228\203\195\232","\224\183\232\210\228\203\195\232","\168\195\212\167","\224\203\193\215\205\185","\190\195\233\205\193","\192\210\201\210\228\183\194","\192\210\201\210\205\209\167\161\196\201","\195\209\202\224\171\213\194","\162\233\205\164\199\210\193","\228\205\164\205\185","\205\212\226\193\168\212","\225\170\183","\224\197\232\185\224\161\193","\161\197\209\186\186\233\210\185","\195\205\161\232\205\185","\228\187\228\203\185","\161\212\185\162\233\210\199","\225\197\233\199\164\195\209\186","\185\208\164\195\209\186","\185\208\164\208","\224\197\194\164\195\209\186","\224\195\213\194\186\195\233\205\194","\183\180\202\205\186","\190\212\193\190\236","\202\232\167\193\210","\195\209\186\225\197\233\199","\224\168\205\161\209\185","\183\216\161\164\185","\202\186\210\194\180\213","\228\193\232\193\213","\228\193\232\181\233\205\167","\181\233\205\167\161\210\195","\202\210\193\210\195\182","\180\233\199\194\161\209\185","\170\232\199\194\180\233\199\194","\224\162\233\210\227\168","\183\211\167\210\185","\193\210\161\161\199\232\210","\185\233\205\194\161\199\232\210","\161\210","\161\213","\161\217","\162\210","\162\213","\162\217","\164\210","\164\213","\164\217","\167\210","\167\213","\167\217","\168\210","\168\213","\168\217","\170\210","\170\213","\170\217","\180\210","\180\213","\180\217","\181\210","\181\213","\181\217","\183\210","\183\213","\183\217","\185\210","\185\213","\185\217","\186\210","\186\213","\186\217","\187\210","\187\213","\187\217","\190\210","\190\213","\190\217","\193\210","\193\213","\193\217","\194\210","\194\213","\194\217","\195\210","\195\213","\195\217","\197\210","\197\213","\197\217","\199\210","\199\213","\199\217","\202\210","\202\213","\202\217","\203\210","\203\213","\203\217","\205\210","\205\213","\205\217","\194\217\232\224\203\195\205\203","\185\232\210\224\186\215\232\205","\161\231\183\211\224\203\205\208","\205\234\194\194\194","\187\228\203\193","\205\194\210\161\183\211"}
local function thaiDictionary(raw,words)
    words=words or THAI_WORDS
    local out,pos={},1
    while pos<=#raw do
        local size,index=0,nil
        for i,word in ipairs(words)do
            if #word>size and raw:sub(pos,pos+#word-1)==word then size=#word;index=i end
        end
        if index then out[#out+1]=string.char(index-1);pos=pos+size
        else
            local b=raw:byte(pos)
            out[#out+1]=(b<=128 and string.char(128)or '')..string.char(b);pos=pos+1
        end
    end
    return table.concat(out)
end
local function unThaiDictionary(raw,words)
    words=words or THAI_WORDS
    local out,pos,size={},1,0
    while pos<=#raw do
        local b=raw:byte(pos);pos=pos+1;local part
        if b==128 then
            local literal=raw:byte(pos);if not literal or literal>128 then return nil end
            part=string.char(literal);pos=pos+1
        elseif b<128 then part=words[b+1];if not part then return nil end
        else part=string.char(b)end
        size=size+#part;if size>4096 then return nil end
        out[#out+1]=part
    end
    return table.concat(out)
end

local Wide=require 'thaichat.wide_dictionary'
local function unpackPayload(mode,encoding,payload,version)
    local raw
    if mode==9 and version==14 then raw=Wide.decode(payload)
    elseif mode==8 and version==13 then raw=unThaiDictionary(payload,THAI_WORDS_V2)
    elseif mode==7 and version==12 then raw=unThaiDictionary(payload)
    elseif mode==0 then raw=payload
    elseif mode==1 and version~=10 then raw=unarithmetic(payload)
    elseif mode==2 and(version==10 or version==11)then raw=unlzw(payload)
    elseif mode==3 and version==11 then raw=undictionary(payload)
    elseif mode>=4 and mode<=6 and version==11 and Native and(encoding==0 or encoding==1)then
        local utf8=Native.usx_decode(payload,mode-4)
        if utf8 then raw=Native.from_utf8(utf8,encoding)end
    end
    if raw and encoding==2 then raw=expand(raw)end
    if raw and(encoding==0 or encoding==1 or encoding==2)then return raw end
end
local CodecOptions={enabled={[0]=true,true,true,true,true,true,true,true,true,true},force='auto'}
local clock=os.clock
pcall(function()
    local ffi=require 'ffi'
    ffi.cdef[[int __stdcall QueryPerformanceCounter(long long*); int __stdcall QueryPerformanceFrequency(long long*);]]
    local frequency,counter=ffi.new('long long[1]'),ffi.new('long long[1]')
    assert(ffi.C.QueryPerformanceFrequency(frequency)~=0)
    clock=function()ffi.C.QueryPerformanceCounter(counter);return tonumber(counter[0])/tonumber(frequency[0])end
end)
local lastBuildMs=0
local function buildUncached(raw,encoding,budget,options)
    options=options or CodecOptions
    local stats={}
    local candidates={{raw,encoding}}
    if encoding==1 then candidates[#candidates+1]={compact(raw),2}end
    local best,bestMode,bestEncoding
    local function consider(payload,mode,e)
        local version=mode==9 and 14 or mode==8 and 13 or mode==7 and 12 or 11
        if payload and #payload<=781 and unpackPayload(mode,e,payload,version)==raw then
            local wire=PHRASE..encode(string.char(mode,e)..payload,version)
            if not stats[mode]or #wire<stats[mode].bytes then stats[mode]={bytes=#wire,encoding=e}end
            if options.enabled[mode]and(options.force=='auto'or options.force==mode)and(not best or #wire<#best)then
                best=wire;bestMode=mode;bestEncoding=e
            end
        end
    end
    for _,candidate in ipairs(candidates)do
        consider(candidate[1],0,candidate[2])
        consider(arithmetic(candidate[1]),1,candidate[2])
        consider(lzw(candidate[1]),2,candidate[2])
        consider(dictionary(candidate[1]),3,candidate[2])
        consider(thaiDictionary(candidate[1]),7,candidate[2])
        consider(thaiDictionary(candidate[1],THAI_WORDS_V2),8,candidate[2])
        consider(Wide.encode(candidate[1]),9,candidate[2])
    end
    if Native then
        local utf8=Native.to_utf8(raw,encoding)
        if utf8 then
            for preset=0,2 do consider(Native.usx_encode(utf8,preset),4+preset,encoding)end
        end
    end
    if not best then return nil,math.huge,nil,nil,stats end
    if #best>budget then return nil,#best,bestMode,bestEncoding,stats end
    return best,#best,bestMode,bestEncoding,stats
end
-- Reuse the exact preview; countdown ticks never recompress unchanged text.
local cache
local function build(raw,encoding,budget,options)
    options=options or CodecOptions
    local key=tostring(options.force)
    for id=0,9 do key=key..(options.enabled[id]and '1'or '0')end
    if cache and cache.raw==raw and cache.encoding==encoding and cache.budget==budget and cache.key==key then
        lastBuildMs=cache.ms;return unpack(cache.result,1,5)
    end
    local started=clock()
    local result={buildUncached(raw,encoding,budget,options)}
    lastBuildMs=(clock()-started)*1000
    cache={raw=raw,encoding=encoding,budget=budget,key=key,result=result,ms=lastBuildMs}
    return unpack(result,1,5)
end
local function restore(text)
    local start=1
    while true do
        local a,b=phraseAt(text,start)
        if not a then return nil end
        local p=b+1
        local v,n1,n2=INDEX[text:byte(p)],INDEX[text:byte(p+1)],INDEX[text:byte(p+2)]
        if(v==8 or v==9 or v==10 or v==11 or v==12 or v==13 or v==14)and n1 and n2 then
            local n=n1*28+n2
            if n>0 and n<=783 then
                local e=p+5+digit_count(n)-1
                local frame=decode(text:sub(p,e))
                if frame and #frame>=2 then
                    local mode,encoding=frame:byte(1,2)
                    local raw=unpackPayload(mode,encoding,frame:sub(3),v)
                    if raw then
                        -- th envelopes only accept Thai bytes/spaces, never ASCII words.
                        local packed=raw
                        if encoding==0 then
                            local utf8=Native and Native.to_utf8(raw,0)
                            packed=utf8 and Native.from_utf8(utf8,1)
                        end
                        if packed then return text:sub(1,a-1)..packed..text:sub(e+1),raw end
                    end
                end
            end
        end
        start=b+1
    end
end
local M={wide=Wide,thaiWordsV2=THAI_WORDS_V2,phrases=PHRASES,randomPhrase=randomPhrase,thaiDictionary=thaiDictionary,unThaiDictionary=unThaiDictionary,options=CodecOptions,arithmetic=arithmetic,dictionary=dictionary,undictionary=undictionary,lzw=lzw,unlzw=unlzw,encode=encode,decode=decode,build=build,restore=restore,compact=compact,expand=expand}
if TEST then _G.THCLAUDE_M=M;return end
local events=require 'samp.events'
local cases={{raw="\202\199\209\202\180\213\164\195\209\186\032\199\209\185\185\213\233\183\216\161\164\185\183\211\205\208\228\195\161\209\185\205\194\217\232",encoding=0},{raw="\195\205\205\194\217\232\203\185\233\210\184\185\210\164\210\195\185\208\164\195\209\186\032\205\213\161\203\233\210\185\210\183\213\224\168\205\161\209\185\032\072\101\108\108\111",encoding=0},{raw="\091\091\116\104\058\202\199\209\202\180\213\032\093\093\072\101\108\108\111\032\207\240\232\226\229\242\032\091\091\117\056\058\240\159\152\128\032\241\144\128\130\093\093",encoding=1},{raw="\161\162\164\167\168\169\170\171\173\174\175\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191\192\193\194\195\197\199\200\201\202\203\204\205\206\161\162\164\167\168\169\170\171\173\174\175\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191\192\193\194\195\197\199\200\201\202\203\204\205\206\161\162\164\167\168\169\170\171\173\174\175\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191\192\193\194\195\197\199\200\201\202\203\204\205\206",encoding=0}}

-- Mixed script order, emoji sequences, item and unresolved slot ID probes.
cases[#cases+1]={raw="\072\101\108\108\111\032\091\091\116\104\058\228\167\032\093\093\207\240\232\226\229\242\032\091\091\117\056\058\240\159\152\128\032\241\144\128\131\032\093\093\091\091\116\104\058\228\183\194\032\093\093\111\107",encoding=1}
cases[#cases+1]={raw="\091\091\117\056\058\240\159\152\142\032\093\093\091\091\116\104\058\228\183\194\032\093\093\091\091\117\056\058\240\159\145\169\240\159\143\189\226\128\141\240\159\146\187\032\241\144\128\136\032\093\093\208\243\241\241\234\232\233\032\069\110\103\108\105\115\104",encoding=1}
cases[#cases+1]={raw="\091\091\116\104\058\228\183\194\032\093\093\065\032\091\091\116\104\058\228\183\194\032\093\093\193\032\091\091\116\104\058\228\183\194\032\093\093\091\091\117\056\058\240\159\153\130\032\241\144\128\138\093\093",encoding=1}
cases[#cases+1]={raw="\091\091\116\104\058\202\199\209\202\180\213\032\093\093\091\091\117\056\058\240\159\135\185\240\159\135\173\032\093\093\049\091\091\117\056\058\239\184\143\226\131\163\032\240\159\145\141\240\159\143\189\032\241\160\128\129\032\093\093\091\091\116\104\058\168\186\093\093",encoding=1}

-- Thai-focused LZW repetition probes, cases 9 and 10.
cases[#cases+1]={raw="\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032",encoding=0}
cases[#cases+1]={raw="\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032",encoding=0}
local prefixes={normal='',s='/s ',me='/me ',b='/b '}
local limits={normal=111,s=99,me=99,b=115}
local queue,nextSend={},0
local LiveModule=require 'thaichat.live_auto'
local liveApi,liveError=LiveModule.bind()
local live=LiveModule.new(liveApi,function(raw,e,budget)
    local wire,n,mode=build(raw,e,budget)
    if wire then wire=randomPhrase(wire,budget);n=wire and #wire or n end
    return wire,n,mode
end,Native,clock,function(message)
    sampAddChatMessage('[CodecLive] '..message,-1)
    local f=io.open(getWorkingDirectory()..'/ThaiChatClaudeProbe.log','ab')
    if f then f:write(os.date('%Y-%m-%d %H:%M:%S'),' LIVE ',message,'\n');f:close()end
end)
local function info(s)sampAddChatMessage('[CodecLabV9] '..s,-1)end
local function hex(s)return(s:gsub('.',function(c)return string.format('%02X',c:byte())end))end
local function log(s)
    local f=io.open(getWorkingDirectory()..'/ThaiChatClaudeProbe.log','ab')
    if f then f:write(os.date('%Y-%m-%d %H:%M:%S'),' V9 ',s,'\n');f:close()end
end
local function incoming(route,text)
    local ok,new,raw=pcall(restore,text)
    if not ok then log('DECODE_ERROR '..route..' '..tostring(new));return end
    if new then log('RESTORED '..route..' raw_hex='..hex(raw)..' wire_hex='..hex(text));return new end
    if text:find(PHRASE,1,true)then log('PHRASE_NOT_DECODED '..route..' hex='..hex(text))end
end
local registerBubble,bubbleError=require('thaichat.carrier_bubble').bind()
if not registerBubble then log('BUBBLE_BRIDGE_UNAVAILABLE '..tostring(bubbleError))end
function events.onServerMessage(color,text)
    local new=incoming('server',text);if new then return{color,new}end
end
function events.onChatMessage(id,text)
    local new=incoming('player',text);if new then return{id,new}end
end
function events.onPlayerChatBubble(id,color,distance,duration,text)
    local new=incoming('bubble',text)
    if new then
        local utf8=Native and Native.to_utf8(new,1)
        local registered=registerBubble and utf8 and registerBubble(id,text,utf8)
        log('BUBBLE_BRIDGE id='..tostring(id)..' registered='..tostring(not not registered))
        return{id,color,distance,duration,new}
    end
end
local json=require 'dkjson'
local SenderEnabled=true
local Ui={visible=false,ready=false,caseId=2,channel='normal',last='',wasCursor=false,openedAt=0,ack=0}
local UiSession=tostring(os.time())..tostring(math.floor(os.clock()*1000000))
local CaseLabels={'Thai sentence','Thai + Hello','Thai / English / Russian / emoji / item',
    'Long Thai (capacity test)','Mixed languages, different order','Emoji ZWJ / skin / mixed',
    'Alternating Thai / Latin / Cyrillic','Flags / keycap / skin / slot','Repeated Thai sentence','Repeated Thai word'}
local UiControl
-- CEF RegWrite2 uses this game-owned root (loader.dll literal). Only our
-- isolated mailbox subkey is read; do not read/change game settings.
local Mailbox=rawget(_G,'THCODEC_MAILBOX')
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
            if adv.RegOpenKeyExA(root,'Software\\ARIZONA GAMES\\NG\\cef\\thaichat_codec_lab',0,1,key)~=0 then return nil end
            local data=ffi.new('unsigned char[1024]');local n=ffi.new('unsigned long[1]',1024);local kind=ffi.new('unsigned long[1]')
            local code=adv.RegQueryValueExA(key[0],'mailbox',nil,kind,data,n);adv.RegCloseKey(key[0])
            if code~=0 or(kind[0]~=1 and kind[0]~=3)or n[0]<1 or n[0]>1024 then return nil end
            return(ffi.string(data,n[0]):gsub('%z+$',''))
        end}
    end)
    if ok then Mailbox=result else log('CEF_MAILBOX_INIT_ERROR '..tostring(result))end
end
local lastMailbox
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
local function cefEval(js)
    js=cefAscii(js)
    if #js>32000 then return false end
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
local function uiState()
    local c=cases[Ui.caseId]
    local wire,n,mode,e,stats=build(c.raw,c.encoding,limits[Ui.channel])
    local utf8=Native.to_utf8(c.raw,c.encoding)or '[Invalid input]'
    local rows,caseList={},{}
    for id=0,9 do rows[#rows+1]={id=id,enabled=CodecOptions.enabled[id],bytes=stats[id]and stats[id].bytes or json.null}end
    for id=1,#cases do caseList[#caseList+1]={id=id,label=CaseLabels[id]or('Case '..id)}end
    local finite=n~=math.huge
    local canSend=wire~=nil and SenderEnabled and #queue==0 and getGameTimer()>=nextSend
    local remaining=math.ceil(math.max(0,nextSend-getGameTimer())/1000)
    local reason=not SenderEnabled and 'Test sending is OFF' or not finite and 'No enabled codec selected' or
        not wire and 'Over budget: this message will NOT be sent' or #queue>0 and 'A test is queued' or
        getGameTimer()<nextSend and ('Wait '..remaining..' seconds') or 'Fits the observed channel budget'
    return {version='PC 1.3 R24',update=Updater and Updater:state()or{phase='error',message=UpdateError or'Updater unavailable',canCheck=false},session=UiSession,ack=Ui.ack,master=SenderEnabled,caseId=Ui.caseId,channel=Ui.channel,force=CodecOptions.force,
        live=live.enabled,liveAvailable=liveApi~=nil,liveStatus=live.status,liveMs=live.ms,
        remaining=remaining,queued=#queue+(live.pending and 1 or 0),computeMs=lastBuildMs,
        text=utf8,rows=rows,cases=caseList,budget=limits[Ui.channel],bytes=finite and n or json.null,
        selectedMode=mode or json.null,canSend=canSend,reason=reason,last=Ui.last,wasCursor=Ui.wasCursor,phrases=PHRASES,phrase=PHRASE}
end
local function uiRefresh()
    if Ui.visible then cefEval('window.__thCodecUI&&window.__thCodecUI.receive('..json.encode(uiState())..');')end
end
local function uiClose()
    Ui.visible=false;Ui.ready=false
    cefEval('window.__thCodecUI&&window.__thCodecUI.destroy();')
    if type(sampToggleCursor)=='function'and not Ui.wasCursor then pcall(sampToggleCursor,false)end
end
local function uiOpen()
    local f=io.open(getWorkingDirectory()..'/resource/thaichat-codec-ui.js','rb')
    if not f then info('Missing resource/thaichat-codec-ui.js');return end
    local js=f:read('*a');f:close()
    local styleFile=io.open(getWorkingDirectory()..'/resource/thaichat-control.css','rb')
    if not styleFile then info('Missing resource/thaichat-control.css');return end
    local css=styleFile:read('*a');styleFile:close()
    Ui.wasCursor=type(sampIsCursorActive)=='function'and sampIsCursorActive()or false
    UiSession=tostring(os.time())..tostring(getGameTimer())..tostring(math.floor(os.clock()*1000000))
    Ui.visible=true;Ui.ready=false;Ui.ack=0;lastMailbox=nil;Ui.openedAt=getGameTimer()
    if not cefEval(js)then Ui.visible=false;info('Could not inject CEF UI.');return end
    local styleJs="(function(){var h=document.getElementById('thaichat-codec-lab');if(h&&h.shadowRoot){var s=document.createElement('style');s.textContent="..json.encode(css)..";h.shadowRoot.appendChild(s);}})();"
    if not cefEval(styleJs)then uiClose();info('Could not inject CEF style.');return end
    if type(sampToggleCursor)=='function'then pcall(sampToggleCursor,true)end
    uiRefresh();log('CEF_UI_OPEN bridge=registry; awaiting local mailbox handshake')
end
UiControl=function(arg)
    local session,action,request,rest=arg:match('^(%S+)%s+(%S+)%s+(%d+)%s*(.*)$')
    if session~=UiSession or not Ui.visible then return end
    if tonumber(request)<=Ui.ack then return end
    Ui.ack=tonumber(request)
    if action=='ready'then Ui.ready=true;log('CEF_UI_READY bridge=registry request='..request);uiRefresh();return end
    if action=='close'then uiClose();return end
    if action=='update_check'and Updater then Updater:check()
    elseif action=='update_install'and Updater then Updater:install()
    elseif action=='update_rollback'and Updater then Updater:rollback()
    elseif action=='live'then live:set(rest=='1')
    elseif action=='toggle'then
        local id,value=rest:match('^(%d)%s+([01])$');id=tonumber(id)
        if id and id<=9 then CodecOptions.enabled[id]=value=='1';queue={}end
    elseif action=='all'and(rest=='0'or rest=='1')then
        for id=0,9 do CodecOptions.enabled[id]=rest=='1'end;queue={}
    elseif action=='master'and(rest=='0'or rest=='1')then SenderEnabled=rest=='1';queue={}
    elseif action=='force'then
        local id=tonumber(rest)
        if rest=='auto'then CodecOptions.force='auto';queue={}
        elseif id and id>=0 and id<=9 and id==math.floor(id)then CodecOptions.force=id;queue={}end
    elseif action=='case'then local id=tonumber(rest);if id and cases[id]and id==math.floor(id)then Ui.caseId=id end
    elseif action=='channel'and prefixes[rest]then Ui.channel=rest
    elseif action=='stop'then queue={};live:cancel();Ui.last='Queue stopped'
    elseif action=='send'then
        if uiState().canSend then
            queue[1]={channel=Ui.channel,case=cases[Ui.caseId],index=Ui.caseId}
            Ui.last='Queued case '..Ui.caseId..' (one message)'
        end
    end
    log('CEF_UI_CONTROL action='..tostring(action)..' request='..request..' value='..tostring(rest))
    uiRefresh()
end
-- Fallback cancellation: UI control commands must never be sent to the server.
function events.onSendCommand(command)
    local arg=command:match('^/thcodecctl%s+(.*)$')
    if arg then UiControl(arg);return false end
end
function onScriptTerminate(script)
    if script==thisScript()then live:set(false);if Ui.visible then pcall(uiClose)end end
end
function main()
    if not Native then sampAddChatMessage('[HybridProbeV4] Missing lib/ThaiChatCodec.dll: '..tostring(nativeError),-1);return end
    while not isSampAvailable()do wait(100)end
    sampRegisterChatCommand('thcodecui',function(arg)
        if arg=='close'or Ui.visible then uiClose()else uiOpen()end
    end)
    sampRegisterChatCommand('thcodecctl',UiControl)
    sampRegisterChatCommand('thcodec',function(arg)
        if arg=='ui'then if Ui.visible then uiClose()else uiOpen()end;return end
        local channel,which=arg:match('^(%S+)%s*(%S*)$')
        channel=channel or 'normal';which=(not which or which=='')and 'all'or which
        if channel=='stop'then queue={};live:cancel();info('Stopped.');return end
        if not SenderEnabled then info('Test sending is OFF. Enable it in /thcodecui.');return end
        if not prefixes[channel]then info('Usage: /thcodec normal|s|me|b [1-10|thai|mixed|all]');return end
        if #queue>0 then info('Probe already queued.');return end
        for i,c in ipairs(cases)do
            if which=='all'or(which=='mixed'and i>=5 and i<=8)or(which=='thai'and(i==1 or i==2 or i>=9))or tonumber(which)==i then queue[#queue+1]={channel=channel,case=c,index=i}end
        end
        if #queue==0 then info('Choose case 1-10, thai, mixed or all.');return end
        info('Queued. Manual test only; sends 8 seconds apart.')
    end)
    math.randomseed(os.time()+getGameTimer())
    live:set(true)
    info('Ready V9: /thcodecui. Real Thai typing uses R23 when available.')
    if not liveApi then info('Live handoff unavailable: '..tostring(liveError))end
    local countdownFont
    if type(renderCreateFont)=='function'then countdownFont=renderCreateFont('Arial',12,5)end
    local lastRefresh=0
    local lastPoll=0
    local lastUpdatePhase
    while true do
        wait(0)
        if UpdateIO then
            local ok,err=pcall(UpdateIO.tick)
            if not ok then Updater.busy=false;Updater.blocked=true;Updater.phase='error';Updater.message=tostring(err);log('UPDATE_ERROR '..tostring(err))end
            if Updater.phase~=lastUpdatePhase then lastUpdatePhase=Updater.phase;log('UPDATE_STATE phase='..Updater.phase..' revision='..Updater.revision..' message='..Updater.message)end
            if Updater.reload then uiClose();thisScript():reload();return end
        end
        local active=type(sampIsChatInputActive)~='function'or sampIsChatInputActive()
        if type(sampIsLocalPlayerSpawned)=='function'and not sampIsLocalPlayerSpawned()then active=false end
        nextSend=live:tick(getGameTimer(),nextSend,active)
        local remaining=math.ceil(math.max(0,nextSend-getGameTimer())/1000)
        if countdownFont and(remaining>0 or live.pending)then
            renderFontDrawText(countdownFont,string.format('Codec: %d queued | wait %d s',#queue+(live.pending and 1 or 0),remaining),30,300,0xFFFFFFFF)
        end
        if Ui.visible and Mailbox and getGameTimer()-lastPoll>=100 then
            lastPoll=getGameTimer()
            local value=Mailbox.read()
            if value and value~=lastMailbox then lastMailbox=value;UiControl(value)end
        end
        if Ui.visible and getGameTimer()-lastRefresh>=1000 then
            if not Ui.ready and getGameTimer()-Ui.openedAt>=4000 then
                info('CEF UI has not acknowledged yet. /thcodecui close can close it.');Ui.openedAt=getGameTimer()+30000
            end
            uiRefresh();lastRefresh=getGameTimer()
        end
        if #queue>0 and getGameTimer()>=nextSend then
            local test=table.remove(queue,1)
            local c=test.case
            local wire,n,mode,encoding=build(c.raw,c.encoding,limits[test.channel])
            if not SenderEnabled then wire=nil end
            if wire then
                wire=randomPhrase(wire,limits[test.channel]);n=#wire
                local restored,raw=restore(wire)
                if restored and raw==c.raw then
                    log('SEND case='..test.index..' channel='..test.channel..' bytes='..n..' mode='..mode..' encoding='..encoding..' raw_hex='..hex(c.raw)..' wire_hex='..hex(wire))
                    sampSendChat(prefixes[test.channel]..wire)
                    Ui.last='Sent case '..test.index..': '..n..' bytes, codec '..mode
                    info('Sent case '..test.index..': '..n..'/'..limits[test.channel]..' bytes.')
                else log('LOCAL_ROUNDTRIP_FAILED');info('Local verification failed; not sent.')end
            else
                log('BLOCKED case='..test.index..' bytes='..n..' budget='..limits[test.channel]..' raw_hex='..hex(c.raw))
                info('Case '..test.index..' does not fit ('..n..' bytes); NOT sent. Test text retained in script.')
                Ui.last='Not sent: case '..test.index..' exceeds budget or no codec enabled'
            end
            nextSend=getGameTimer()+8000
        end
    end
end
