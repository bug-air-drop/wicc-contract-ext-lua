mylib = require "mylib"

------------------------------------------------------------------------------------
-- notice:
-- 注意: 以下是对配置当前合约的发行参数, 请修改也只能修改以下区域的参数

_G.Config={
    -- the waykichain contract stardard, if you do not know the waykichain stardard, please do not change it.
    -- 表示符合的维基链合约标准,在此处您不该修改这个值.
    standard = "WS1802",

    -- the contract ownder address, please write the right address.
    -- 表示合约的拥有者, 当初始化这个合约时, 会将发行的token转入此地址中.
    owner = "wgsGSfuznCXjfGTyo7d14eznNFX5BqZEws",

    -- the contract name
    -- 合约的名称, 也是当前合约代表的WaykiToken的名称
    name = "ICO Sample",

    -- the contract symbol
    -- WaykiToken的符号
    symbol = "ICOS",

    -- the contract coin total supply，100000000 is for decimal, the decimal digits is 8.
    -- 初始发行的WaykiToken总数
    totalSupply = 210000000 * 100000000
}

------------------------------------------------------------------------------------

-- internal method and table
_G.LibHelp={
    StandardKey={
        standard = "standard",
        owner = "owner",
        name = "name",
        symbol = "symbol",
    },
    OP_TYPE = {
        ADD_FREE = 1,
        SUB_FREE = 2
    },
    ADDR_TYPE = {
        REGID  = 1,
        BASE58 = 2
    },
    TableIsNotEmpty = function (t)
        return _G.next(t) ~= nil
    end,
    Unpack = function (t,i)
        i = i or 1
        if t[i] then
          return t[i], _G.LibHelp.Unpack(t,i+1)
        end
    end,
    LogMsg = function (msg)
        local logTable = {
             key = 3,
             length = string.len(msg),
             value = msg
       }
       _G.mylib.LogPrint(logTable)
    end,
    GetContractValue = function (key)
        assert(#key > 0, "Key is empty")
        local tValue = { _G.mylib.ReadData(key) }
        if _G.LibHelp.TableIsNotEmpty(tValue) then
          return true,tValue
        else
            _G.LibHelp.LogMsg("Key not exist")
          return false,nil
        end
    end,
    GetContractTxParam = function (startIndex, length)
        assert(startIndex > 0, "GetContractTxParam start error(<=0).")
        assert(length > 0, "GetContractTxParam length error(<=0).")
        assert(startIndex+length-1 <= #_G.contract, "GetContractTxParam length ".. length .." exceeds limit: " .. #_G.contract)
        local newTbl = {}
        for i = 1,length do
          newTbl[i] = _G.contract[startIndex+i-1]
        end
        return newTbl
    end,
    WriteAppData = function (opType, moneyTbl, userIdTbl)
        local appOperateTbl = {
          operatorType = opType,
          outHeight = 0,
          moneyTbl = moneyTbl,
          userIdLen = #userIdTbl,
          userIdTbl = userIdTbl,
          fundTagLen = 0,
          fundTagTbl = {}
        }
        assert(_G.mylib.WriteOutAppOperate(appOperateTbl), "WriteAppData: ".. opType .." op err")
    end,
    GetFreeTokenCount = function (accountTbl)
        local freeMoneyTbl = { _G.mylib.GetUserAppAccValue( {idLen = #accountTbl, idValueTbl = accountTbl} ) }
        assert(_G.LibHelp.TableIsNotEmpty(freeMoneyTbl), "GetUserAppAccValue error")
        return _G.mylib.ByteToInteger(_G.LibHelp.Unpack(freeMoneyTbl))
    end,
    TransferToken = function (fromAddrTbl, toAddrTbl, moneyTbl)
        local money = _G.mylib.ByteToInteger(_G.LibHelp.Unpack(moneyTbl))
        assert(money > 0, money .. " <=0 error")
        local freeMoney = _G.LibHelp.GetFreeTokenCount(fromAddrTbl)
        assert(freeMoney >= money, "Insufficient money to transfer in the account.")
        _G.LibHelp.WriteAppData(_G.LibHelp.OP_TYPE.SUB_FREE, moneyTbl, fromAddrTbl )
        _G.LibHelp.WriteAppData(_G.LibHelp.OP_TYPE.ADD_FREE, moneyTbl, toAddrTbl )
    end,
    GetCurrTxAccountAddress = function ()
        return {_G.mylib.GetBase58Addr(_G.mylib.GetCurTxAccount())}
    end
}

-- contract method for caller
_G.ICO={
    TX_TYPE =
    {
      CONFIG = 0x11,
      SEND_ASSET = 0x16,
    },
    Send=function ()
        local base58Addr = _G.LibHelp.GetCurrTxAccountAddress()
        assert(_G.LibHelp.TableIsNotEmpty(base58Addr),"GetBase58Addr error")
        local pos = 5
        local toAddrTbl = _G.LibHelp.GetContractTxParam(pos, 34)
        pos = pos + 34
        local moneyTbl = _G.LibHelp.GetContractTxParam(pos, 8)
        _G.LibHelp.TransferToken(base58Addr, toAddrTbl, moneyTbl)
    end,
    Config=function ()
        -- check contract statu
        assert(_G.LibHelp.GetContractValue("name")==false,"Already configured")

        -- write down standard key
        for k,v in pairs(_G.LibHelp.StandardKey) do
            if _G.Config[k] then
                local value = {string.byte(_G.Config[k],1,string.len(_G.Config[k]))}
                local writOwnerTbl = {
                    key = v,
                    length = #value,
                    value = value
                }
                assert(_G.mylib.WriteData(writOwnerTbl),'can not issue tokens, failed to write the key='..v..' value='.._G.Config[k])
            else
                error('can not issue tokens, failed to read the key='..k)
            end
        end

        -- issue tokens
        local totalSupplyTbl =  {_G.mylib.IntegerToByte8(_G.Config.totalSupply)}
        _G.LibHelp.WriteAppData(_G.LibHelp.OP_TYPE.ADD_FREE, totalSupplyTbl,{string.byte(_G.Config.owner,1,string.len(_G.Config.owner))})

        print(string.format('contract config success, name: %s , issuer: %s',_G.Config.name,_G.Config.owner))
      end
}

------------------------------------------------------------------------------------

assert(#_G.contract >=2, "Parameter length error (<2): " ..#_G.contract)
assert(_G.contract[1] == 0xf0, "Parameter MagicNo error (~=0xf0): " .. _G.contract[1])

if _G.contract[2] == _G.ICO.TX_TYPE.CONFIG then
    _G.ICO.Config()
elseif _G.contract[2] == _G.ICO.TX_TYPE.SEND_ASSET and #_G.contract==2+2+34+8 then
    _G.ICO.Send()
else
    error(string.format("Method %02x not found or parameter error", _G.contract[2]))
end
