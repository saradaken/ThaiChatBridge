-- Immutable shared dictionary. DP chooses minimum bit cost, not longest word.
local data=require 'thaichat.wide_dictionary_data'
local EXPECTED_ADLER=367178747 -- filled by prepare.py from the frozen data
local a,b=1,0
for pos=1,#data do a=(a+data:byte(pos))%65521;b=(b+a)%65521 end
assert(b*65536+a==EXPECTED_ADLER,'wide dictionary fingerprint mismatch')
local words,index,lengths={}, {},{}
for word in data:gmatch('[^\n]+')do
    assert(not index[word],'duplicate dictionary entry')
    words[#words+1]=word;index[word]=#words-1
    local first=word:byte(1);lengths[first]=lengths[first]or{}
    lengths[first][#word]=true
end
local bits=0;while 2^bits<#words do bits=bits+1 end
assert(#words>128 and bits<=18,'unexpected wide dictionary size')
for first,set in pairs(lengths)do
    local list={};for size in pairs(set)do list[#list+1]=size end
    table.sort(list);lengths[first]=list
end
local M={count=#words,bits=bits}
function M.encode(raw)
    local n=#raw;if n>4096 then return nil end
    local costs,choices={[n+1]=0},{}
    for pos=n,1,-1 do
        local cost,choice=9+costs[pos+1],nil
        for _,size in ipairs(lengths[raw:byte(pos)]or{})do
            if pos+size-1>n then break end
            local id=index[raw:sub(pos,pos+size-1)]
            if id then
                local candidate=(id<128 and 9 or 2+bits)+costs[pos+size]
                if candidate<cost then cost=candidate;choice={id,size}end
            end
        end
        costs[pos]=cost;choices[pos]=choice
    end
    local out={string.char(math.floor(n/256),n%256)};local buffer,used=0,0
    local function emit(value,width)
        buffer=buffer*2^width+value;used=used+width
        while used>=8 do
            used=used-8;out[#out+1]=string.char(math.floor(buffer/2^used));buffer=buffer%2^used
        end
    end
    local pos=1
    while pos<=n do
        local choice=choices[pos]
        if choice then
            emit(choice[1]<128 and 2 or 3,2);emit(choice[1],choice[1]<128 and 7 or bits);pos=pos+choice[2]
        else emit(0,1);emit(raw:byte(pos),8);pos=pos+1 end
    end
    if used>0 then out[#out+1]=string.char(buffer*2^(8-used))end
    return table.concat(out)
end
function M.decode(payload)
    if #payload<2 then return nil end
    local n=payload:byte(1)*256+payload:byte(2);if n>4096 then return nil end
    local cursor=16
    local function read(width)
        if cursor+width>#payload*8 then return nil end
        local value=0
        for _=1,width do
            value=value*2+math.floor(payload:byte(math.floor(cursor/8)+1)/2^(7-cursor%8))%2;cursor=cursor+1
        end
        return value
    end
    local out,size={},0
    while size<n do
        local kind=read(1);if kind==nil then return nil end
        local part
        if kind==0 then local b=read(8);if b==nil then return nil end;part=string.char(b)
        else
            local wide=read(1);if wide==nil then return nil end
            local id=read(wide==0 and 7 or bits)
            if not id or(wide==1 and id<128)then return nil end
            part=words[id+1];if not part then return nil end
        end
        size=size+#part;if size>n then return nil end
        out[#out+1]=part
    end
    local remaining=#payload*8-cursor
    if remaining>7 or(remaining>0 and read(remaining)~=0)then return nil end
    return table.concat(out)
end
return M
