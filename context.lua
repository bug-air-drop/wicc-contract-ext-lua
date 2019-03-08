mylib = require "mylib"

_G.Context = {
    _Version = "1.0.2 preview",
    _Author = "Mr.Meeseeks",
    _Site = "https://github.com/GitHubbard/wicc-contract-ext-lua",
    Lib = require "mylib",
    _errmsg='',
    _t="table",
    _s="string",
    _n="number",
    Event = {},
    Contract = {},
    CallDomain = 0x00,
    CallFunc = 0x00,
    RecvData = {},
    CurTxAddr = nil,
    CurTxPayAmount = nil,
    GetCurTxAddr = function()
        if _G._C.CurTxAddr == nil then
            local addr = _G.Hex:New({_G._C.Lib.GetBase58Addr(_G._C.Lib.GetCurTxAccount())})
            assert(addr:IsEmptyOrNil() == false or _G._err(0500,'GetBase58Addr'),_G._errmsg)
            _G._C.CurTxAddr = addr:ToString()
        end
        return _G._C.CurTxAddr
    end,
    GetCurTxPayAmount = function()
        if _G._C.CurTxPayAmount == nil then
            local amount = _G.Hex:New({_G._C.Lib.GetCurTxPayAmount()})
            assert(amount:IsEmptyOrNil() == false or _G._err(0500,'GetCurTxPayAmount'),_G._errmsg)
            _G._C.CurTxPayAmount = amount:ToInt()
        end
        return _G._C.CurTxPayAmount
    end,
    IHexArray = {
        Posit = 1,
        New = function(s, d)
            local mt = {}
            if (type(d) == _G._C._s) then
                for i = 1, #d do
                    table.insert(mt, string.byte(d, i))
                end
            elseif d ~= nil then
                mt = d
            end
            setmetatable(mt, s)
            s.__index = s
            s.__eq = _G.Hex.__eq
            s.__tostring = _G.Hex.ToString
            s.__concat = _G.Hex.__concat
            return mt
        end,
        Appand = function(s, t)
            for i=1,#t do
                s[#s+1] = t[i]
            end
            return s
        end,
        Embed = function(s,start,t)
            for i=1,#t do
                s[i+start-1] = t[i]
            end
            return s
        end,
        Select = function(s, start, len)
            assert((#s >= start + len - 1) or _G._err(0004),_G._errmsg)
            local newt = {}
            for i=1,len do
                newt[i] = s[start+i-1]
            end
            return _G.Hex:New(newt)
        end,
        Skip = function(s, count)
            local newt = {}
            for i=1,#s do
                newt[i] = s[count + i]
            end
            return _G.Hex:New(newt)
        end,
        Take = function(s, len)
            local newt = {}
            for i=1,len do
                newt[i] = s[i]
            end
            return _G.Hex:New(newt)
        end,
        Next = function(s, len)
            local newt = {}
            for i=1,len do
                assert(#s >= s.Posit or _G._err(0004),_G._errmsg)
                newt[i] = s[s.Posit]
                s.Posit = s.Posit + 1
            end
            return _G.Hex:New(newt)
        end,
        IsEmpty = function(s)
            return #s==0
        end,
        IsEmptyOrNil = function(s)
            return _G.next(s) == nil or #s == 0
        end,
        ToString = function(s)
            local str = ""
            for i=1,#s do
                str = str .. string.format("%c", s[i])
            end
            return str
        end,
        ToHexString = function(s)
            local str = ""
            for i=1,#s do
                str = str .. string.format("%02x", s[i])
            end
            return str
        end,
        ToInt = function(s)
            if #s<4 then
                s=s:Appand({0x00,0x00,0x00}):Take(4)
            elseif #s>4 and #s<8 then
                s=s:Appand({0x00,0x00,0x00}):Take(8)
            end
            assert(#s==4 or #s==8 or _G._err(0001,#s),_G._errmsg)
            return _G._C.Lib.ByteToInteger(s:Unpack())
        end,
        ToUInt = function(s)
            local value=s:ToInt()
            assert(value>=0 or _G._err(0105,value),_G._errmsg)
            return value
        end,
        Unpack = function(s)
            return _G.Hex.__expand(s)
        end,
        Fill = function(s, t)
            local filled = {}
            if t.Loop then
                filled = s:__fillloop(t)
            else
                for i=1,#t,2 do
                    local k  = t[i]
                    local v  = t[i+1]
                    local vt = type(v)
                    if vt == _G._C._t then
                        if v.Loop then
                            filled[k] = s:__fillloop(v)
                        elseif #v==1 then
                            filled[k] = s:Next(v[1])
                        elseif v.Len then
                            local cell = s:Next(v.Len)
                            if v.Model then
                                cell = cell:Fill(v.Model)
                            else
                                cell = cell:Fill(v)
                            end
                            filled[k] = cell
                        else
                            assert(_G._err(0005),_G._errmsg)
                        end
                    elseif vt == _G._C._s then
                        filled[k] = s:Next(tonumber(v)):ToString()
                    elseif vt == _G._C._n then
                        filled[k] = s:Next(v):ToInt()
                    end
                end
            end
            return filled
        end,
        __fillloop=function(s,t)
            local endPosit = #s
            if t.Loop < 0 then
                t.Loop = s:Next(math.abs(t.Loop)):ToInt()
            end
            if t.Loop > 0 then
                endPosit = s.Posit+(t.Loop*t.Len)-1
            end
            local subt = {}
            while endPosit>=s.Posit do
                local cell = s:Next(t.Len)
                if t.Model then
                    cell = cell:Fill(t.Model)
                end
                table.insert(subt, cell)
            end
            return subt
        end,
        __expand = function(t, i)
            i = i or 1
            if t[i] then
                return t[i], _G.Hex.__expand(t, i + 1)
            end
        end,
        __concat = function(s, t)
            return s:ToString()..t
        end,
        __eq = function(s, t)
            if (#s ~= #t) then
                return false
            end
            for i = #s, 1, -1 do
                if s[i] ~= t[i] then
                    return false
                end
            end
            return true
        end
    },
    IAppData = {
        SafeRead = function(key)
            assert(#key > 1 or _G._err(0001,#key),_G._errmsg)
            local value = _G.Hex:New({_G._C.Lib.ReadData(key)})
            if value.IsEmpty() then
                return false, nil
            else
                return true, value
            end
        end,
        Read = function(key)
            assert(#key > 1 or _G._err(0001,#key),_G._errmsg)
            local value = _G.Hex:New({_G._C.Lib.ReadData(key)})
            return value
        end,
        Write = function(key, value)
            assert(type(key) == _G._C._s or _G._err(0002,type(key)),_G._errmsg)
            if type(value) == _G._C._s then
                value = _G.Hex:New(value)
            elseif type(value) == _G._C._n then
                value = {_G._C.Lib.IntegerToByte8(value)}
            end
            local writeDbTbl = {key = key, length = #value, value = value}
            assert(_G._C.Lib.WriteData(writeDbTbl) or _G._err(0500,'WriteAppData'),_G._errmsg)
        end,
        Modify = function(key, value)
            assert(type(key) == _G._C._s or _G._err(2,type(key)),_G._errmsg)
            local writeDbTbl = {key = key, length = #value, value = value}
            assert(_G._C.Lib.ModifyData(writeDbTbl) or _G._err(0500,'ModifyAppData'),_G._errmsg)
        end,
        Delete = function(key)
            assert(type(key) == _G._C._s or _G._err(2,type(key)),_G._errmsg)
            assert(_G._C.Lib.DeleteData(key) or _G._err(0500,'DeleteData'),_G._errmsg)
        end
    },
    IAsset = {
        NET_ASSET_OP = {
            ADD = 1,
            SUB = 2
        },
        APP_ASSET_OP = {
            ADD = 1,
            SUB = 2,
            ADD_FREEZED = 3,
            SUB_FREEZED = 4
        },
        ADDR_TYPE = {
            REGID = 1,
            BASE58 = 2
        },
        SendSelfNetAsset = function(toAddr, money)
            if type(toAddr) == _G._C._s then
                toAddr = _G.Hex:New(toAddr)
            end
            if type(money) == _G._C._n then
                money = _G.Hex:New({_G._C.Lib.IntegerToByte8(money)})
            end
            assert(#toAddr == 34 or #toAddr == 6 or _G._err(0102,toAddr,#toAddr),_G._errmsg)
            assert(money:ToInt() > 0 or _G._err(0105,money:ToInt()),_G._errmsg)
            local tb = {
                addrType = (#toAddr == 6 and _G._C.IAsset.ADDR_TYPE.REGID) or _G._C.IAsset.ADDR_TYPE.BASE58,
                accountIdTbl = toAddr,
                operatorType = _G._C.IAsset.NET_ASSET_OP.ADD,
                outHeight = 0,
                moneyTbl = money
            }
            assert(_G._C.Lib.WriteOutput(tb) or _G._err(0108),_G._errmsg)
            tb.addrType = _G._C.IAsset.ADDR_TYPE.REGID
            tb.operatorType = _G._C.IAsset.NET_ASSET_OP.SUB
            tb.accountIdTbl = {_G._C.Lib.GetContractRegId()}
            assert(money:ToInt() < _G._C.IAsset.GetNetAsset(tb.accountIdTbl) or _G._err(0106),_G._errmsg)
            assert(_G._C.Lib.WriteOutput(tb) or _G._err(0108),_G._errmsg)
            return true
        end,
        GetNetAsset = function(addr)
            if type(addr) == _G._C._s then
                addr = _G.Hex:New(addr)
            end
            assert(#addr == 34 or #addr == 6 or _G._err(0100,addr,#addr),_G._errmsg)
            local mtb = _G.Hex:New({_G._C.Lib.QueryAccountBalance(_G.Hex.Unpack(addr))})
            assert(#mtb > 0 or _G._err(0500,'QueryAccountBalance'),_G._errmsg)
            return mtb:ToInt()
        end,
        GetAppAsset = function(addr)
            local mtb = _G.Hex:New({_G._C.Lib.GetUserAppAccValue({idLen = #addr, idValueTbl = addr})})
            assert(#mtb > 0 or _G._err(0500,'GetUserAppAccValue'),_G._errmsg)
            return mtb:ToInt()
        end,
        AddAppAsset = function(toAddr, money)
            if type(toAddr) == _G._C._s then
                toAddr = _G.Hex:New(toAddr)
            end
            if type(money) == _G._C._n then
                money = _G.Hex:New({_G._C.Lib.IntegerToByte8(money)})
            end
            assert(#toAddr == 34 or _G._err(0102,toAddr,#toAddr),_G._errmsg)
            assert(money:ToInt() > 0 or _G._err(0105,money:ToInt()),_G._errmsg)
            local tb = {
                operatorType = _G._C.IAsset.APP_ASSET_OP.ADD,
                outHeight = 0,
                moneyTbl = money,
                userIdLen = #toAddr,
                userIdTbl = toAddr,
                fundTagLen = 0,
                fundTagTbl = {}
            }
            assert(_G._C.Lib.WriteOutAppOperate(tb) or _G._err(0500,'WriteOutAppOperate'),_G._errmsg)
            return true
        end,
        SubAppAsset = function(fromAddr, money)
            if type(fromAddr) == _G._C._s then
                fromAddr = _G.Hex:New(fromAddr)
            end
            if type(money) == _G._C._n then
                money = _G.Hex:New({_G._C.Lib.IntegerToByte8(money)})
            end
            assert(#fromAddr == 34 or _G._err(0100,fromAddr,#fromAddr),_G._errmsg)
            assert(money:ToInt() > 0 or _G._err(0105,money:ToInt()),_G._errmsg)
            assert(_G._C.IAsset.GetAppAsset(fromAddr) >= money:ToInt() or _G._err(0106),_G._errmsg)
            local tb = {
                operatorType = _G._C.IAsset.APP_ASSET_OP.SUB,
                outHeight = 0,
                moneyTbl = money,
                userIdLen = #fromAddr,
                userIdTbl = fromAddr,
                fundTagLen = 0,
                fundTagTbl = {}
            }
            assert(_G._C.Lib.WriteOutAppOperate(tb) or _G._err(0500,'WriteOutAppOperate'),_G._errmsg)
            return true
        end,
        SendAppAsset = function(fromAddr, toAddr, money)
            if type(fromAddr) == _G._C._s then
                fromAddr = _G.Hex:New(fromAddr)
            end
            if type(toAddr) == _G._C._s then
                toAddr = _G.Hex:New(toAddr)
            end
            if type(money) == _G._C._n then
                money = _G.Hex:New({_G._C.Lib.IntegerToByte8(money)})
            end

            assert(#fromAddr == 34 or _G._err(0101,fromAddr,#fromAddr),_G._errmsg)
            assert(#toAddr == 34 or _G._err(0102,toAddr,#toAddr),_G._errmsg)
            assert(fromAddr ~= toAddr or _G._err(0103),_G._errmsg)
            assert(money:ToInt() > 0 or _G._err(0105,money:ToInt()),_G._errmsg)
            assert(_G._C.IAsset.GetAppAsset(fromAddr) >= money:ToInt() or _G._err(0106,money:ToInt()),_G._errmsg)

            local tb = {
                operatorType = _G._C.IAsset.APP_ASSET_OP.SUB,
                outHeight = 0,
                moneyTbl = money,
                userIdLen = #fromAddr,
                userIdTbl = fromAddr,
                fundTagLen = 0,
                fundTagTbl = {}
            }
            assert(_G._C.Lib.WriteOutAppOperate(tb) or _G._err(0500,'WriteOutAppOperate'),_G._errmsg)

            tb = {
                operatorType = _G._C.IAsset.APP_ASSET_OP.ADD,
                outHeight = 0,
                moneyTbl = money,
                userIdLen = #toAddr,
                userIdTbl = toAddr,
                fundTagLen = 0,
                fundTagTbl = {}
            }
            assert(_G._C.Lib.WriteOutAppOperate(tb) or _G._err(0500,'WriteOutAppOperate'),_G._errmsg)
            return true
        end
    },
    Log = function(msg)
        assert(#msg >= 1 or _G._err(0001,#msg),_G._errmsg)
        assert(type(msg) == _G._C._s or _G._err(0002,type(msg)),_G._errmsg)
        _G._C.Lib.LogPrint({key = 0, length = #msg, value = msg})
        return msg
    end,
    _err=function(code,...)
        _G._errmsg= string.format('{"code":"%s"}',code,...)
        return false
    end,
    Init = function(...)
        if _G._C == nil then
            _G._C = _G.Context
            _G.Hex = _G._C.IHexArray
            _G.AppData = _G._C.IAppData
            _G.Asset = _G._C.IAsset
            _G.Log = _G._C.Log
            _G._err=_G._C._err
            _G._errmsg=_G._C._errmsg
            for k ,v in pairs({ ... }) do
                if v.Init ~= nil then
                    v.Init()
                end
            end
        end
        return _G._C
    end,
    LoadContract = function()
        if #_G.contract > 0 then
            _G._C.Contract = _G.Hex:New(_G.contract)
            _G._C.CallDomain = _G._C.Contract[1]
            _G._C.CallFunc   = _G._C.Contract[2]
            _G._C.RecvData   = _G._C.Contract:Skip(2)
            _G.RecvData = _G._C.RecvData
        end
    end,
    Main = function()
        _G.Context.Init()
        _G._C.LoadContract()
        if _G._C.Event[_G._C.CallDomain] and _G._C.Event[_G._C.CallDomain][_G._C.CallFunc] then
            _G._C.Event[_G._C.CallDomain][_G._C.CallFunc]()
        else
            assert(_G._err(0404,_G._C.CallFunc),_G._errmsg)
        end
    end
}

_G.ErrExt={
    json=true,
    Init=function()
        _G._err=_G.ErrExt.GetErrorMsg
        _G.ErrExt[0001]='content lenght invalid, lenght=%s'
        _G.ErrExt[0002]='content type error, type=%s'
        _G.ErrExt[0003]='array is empty'
        _G.ErrExt[0004]='index out of range'
        _G.ErrExt[0005]='unknow template'
        _G.ErrExt[0100]='address is invaild, input=%s, len=%s'
        _G.ErrExt[0101]='sender address is invaild, input=%s, len=%s'
        _G.ErrExt[0102]='receiver address is invaild, input=%s, len=%s'
        _G.ErrExt[0103]='the sender cannot be the same as the receiver'
        _G.ErrExt[0104]='amount is invaild, len=%s'
        _G.ErrExt[0105]='the value should not be less than 0, input=%s'
        _G.ErrExt[0106]='insufficient account balance'
        _G.ErrExt[0107]='WriteOutAppOperate Func Error'
        _G.ErrExt[0108]='WriteOutput Func Error'
        _G.ErrExt[0401]='operation not permitted'
        _G.ErrExt[0404]='domain or method not found, call:%s'
        _G.ErrExt[0500]='an exception occurred during a mylib call, method:%s'
        --add you error msg here
    end,
    GetErrorMsg = function(code,...)
        if _G.ErrExt[code] then
            local s = (_G.ErrExt.json and '{"code":"%s","msg":"%s"}')
                        or 'errcode=%s, msg=%s'
            _G._errmsg=string.format(s,code,string.format(_G.ErrExt[code],...))
        else
            local s = (_G.ErrExt.json and '{"code":"%s","msg":"unknow exception"}')
                        or 'unknow exception,errcode=%s'
            _G._errmsg=string.format(s,code,...)
        end
        return false,_G._errmsg
    end
}

_G.ContextTestUnit={
    Init=function()
        _G._C.Event[0xaa]=_G.ContextTestUnit
        _G.ContextTestUnit[0xaa]=_G.ContextTestUnit.HexArrayTest
        _G.ContextTestUnit[0x01]=_G.ContextTestUnit.GetCurTxAddrTest
        _G.ContextTestUnit[0x02]=_G.ContextTestUnit.GetCurTxPayAmountTest
        _G.ContextTestUnit[0x03]=_G.ContextTestUnit.AppDataWrtieTest
        _G.ContextTestUnit[0x04]=_G.ContextTestUnit.AppDataReadTest
        _G.ContextTestUnit[0x05]=_G.ContextTestUnit.AppDataReadIntTest
        _G.ContextTestUnit[0x06]=_G.ContextTestUnit.AppDataDeleteTest
        _G.ContextTestUnit[0x07]=_G.ContextTestUnit.AppDataModifyTest
        _G.ContextTestUnit[0x08]=_G.ContextTestUnit.GetNetAssetTest
        _G.ContextTestUnit[0x09]=_G.ContextTestUnit.GetNetAssetTest2
        _G.ContextTestUnit[0x10]=_G.ContextTestUnit.ShowMeTheMoney
        _G.ContextTestUnit[0x11]=_G.ContextTestUnit.SubAppAssetTest
        _G.ContextTestUnit[0x12]=_G.ContextTestUnit.SendAppAssetTest
        _G.ContextTestUnit[0x13]=_G.ContextTestUnit.HexFillTest
        _G.ContextTestUnit[0x14]=_G.ContextTestUnit.HexFillTest2
        _G.ContextTestUnit[0x15]=_G.ContextTestUnit.HexFillTest3
        --TODO
    end,
    HexArrayTest=function()
        local str="I'm Mr.Meeseeks~Look at me~"
        local ha=_G.Hex:New(str)
        local str2=ha:ToString()
        error('[OK]len='..#ha..' type='..type(ha)..' print='..str2)
    end,
    GetCurTxAddrTest = function()
        local curaddr = _G.Context.GetCurTxAddr()
        error('[OK]CurTxAddr='..curaddr)
    end,
    GetCurTxPayAmountTest=function()
        local amount = _G.Context.GetCurTxPayAmount()
        error('[OK]CurTxPayAmount='..amount)
    end,
    AppDataWrtieTest=function()
        local key   = _G.Context.RecvData:Next(2):ToString()
        local value = _G.Context.RecvData:Skip(2)
        print('[OK]AppDataWrtieTest , Key='..key..' , Value='..value:ToHexString())
        _G.AppData.Write(key,value)
    end,
    AppDataReadTest=function()
        local key   = _G.Context.RecvData:Take(2):ToString()
        local value = _G.AppData.Read(key)
        local info  = '[OK]AppDataReadTest , Key='..key..' , ValueHex='..value:ToHexString()..' , Value='..value:ToString()..' , Len='..#value
        print(info)
        error(info)
    end,
    AppDataReadIntTest=function()
        local key   = _G.Context.RecvData:Select(1,2):ToString()
        local value = _G.AppData.Read(key)
        local info  = '[OK]AppDataReadTest , Key='..key..' , ValueHex='..value:ToHexString()..' , Value='..value:ToInt()..' , Len='..#value
        print(info)
        error(info)
    end,
    AppDataDeleteTest=function()
        local key   = _G.Context.RecvData:Next(2):ToString()
        local value = _G.AppData.Delete(key)
        local info  = '[OK]AppDataDeleteTest , Key='..key
        print(info)
        print(value)
    end,
    AppDataModifyTest=function()
        local key   = _G.Context.RecvData:Next(2):ToString()
        local value = _G.Context.RecvData:Skip(2)
        print('AppDataModifyTest , Key='..key..' , Value='..value:ToHexString())
        _G.AppData.Modify(key,value)
    end,
    GetNetAssetTest=function()
        local curaddr = _G.Context.GetCurTxAddr()
        local txAddrMoney=_G.Asset.GetNetAsset(curaddr)
        error('byBase58='..txAddrMoney)
    end,
    GetNetAssetTest2=function()
        local accountTbl = _G.Hex:New({_G.Context.Lib.GetContractRegId()})
        local txAddrMoney1=_G.Asset.GetNetAsset(accountTbl)
        local txAddrMoney2=_G.Asset.GetNetAsset({_G.Context.Lib.GetContractRegId()})
        error('byRegId1='..txAddrMoney1..' byRegId2='..txAddrMoney2)
    end,
    ShowMeTheMoney=function()
        local curaddr = _G.Context.GetCurTxAddr()
        _G.Asset.AddAppAsset(curaddr,1000000)
    end,
    SubAppAssetTest=function()
        local curaddr = _G.Context.GetCurTxAddr()
        _G.Asset.SubAppAsset(curaddr,100000)
    end,
    SendAppAssetTest=function()
        local curaddr = _G.Context.GetCurTxAddr()
        local tx = _G._C.RecvData:Fill({"to",'34',"money",8})
        _G.Log('send money='..tx.money..' to '..tx.to)
        _G.Asset.SendAppAsset(curaddr,tx.to,tx.money)
    end,
    HexFillTest=function()
        local tx  = _G._C.RecvData:Fill({"str","2","int",2,"model",{Len=4,"str1","2","str2","2"}})
        local txdata="tx.str="..tx.str..' tx.int='..tx.int..' tx.model.str1='..tx.model.str1
        error(txdata)
    end,
    HexFillTest2=function()
        local tx  = _G._C.RecvData:Fill({"model",{Loop=2,Len=2}})
        local txdata="tx.model[1]="..tx.model[1]:ToString().." tx.model[2]="..tx.model[2]:ToString()
        error(txdata)
    end,
    HexFillTest3=function()
        local txs  = _G._C.RecvData:Fill({Loop=0,Len=4,Model={"to","2","money",2}})
        local txdata=''
        for i = 1, #txs do
            txdata=txdata..' ['..i..'] to='..txs[i].to..' money='..txs[i].money
        end
        error(txdata)
    end
}

_G.Context.Init(_G.ErrExt,_G.ContextTestUnit).Main()

--aaaa  检测Hex数组是否能正常实例化
--aa01  获取当前调用合约的用户地址
--aa02  获取当前调用合约时向合约地址转账的WICC金额
--aa0361616262  将key=aa  value=bb 的键值对数据写入链上
--aa0363630100000000000000 将 key=cc value=0100000000000000的键值对数据写入链上, 其中value可转为数值1
--aa046161  测试是否可以将key为aa的值读出
--aa056363  测试是否可以将key为cc的值读出, 返回转换后的数值
--aa0761616363  将key为aa的值修改为cc
--aa08  通过查询地址余额的方式获取当前合约账户的wicc余额
--aa09  通过查询regid余额的方式获取当前合约账户的wicc余额
--aa10  使得当前调用合约的账户获得0.001的token
--aa11  扣去当前调用合约的账户0.0001个token
--aa12 774c383343427177734e46344e41455775316751795964584454755a5a7137736659 6400000000000000 转token到指定账户
--aa13 6161 0100 62626363 反序列化填充数据
--aa14 6161 6262 反序列化填充数据
--aa15 61610100 62620200 63630300 ... 反序列化填充数据
