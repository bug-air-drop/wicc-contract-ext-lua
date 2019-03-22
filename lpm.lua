_G.DynSource={
    Init=function()
        _G._C.Main=_G.DynSource.Main
    end,
    Main = function()
        _G.Context.Init()
        _G._C.Contract = _G.Hex:New(_G.contract)
        local name=_G._C.Contract:Take(20):ToString()
        local authorKey=name..'-author'
        local versionKey=name..'-version'
        local updateKey=name..'-update'
        local recordAuthor=_G.AppData.Read(authorKey):ToString()

        assert(#recordAuthor==0 or recordAuthor==_G._C.GetCurTxAddr() or _G._err(1001,recordAuthor),_G._errmsg)

         if #recordAuthor==0 then
            _G.AppData.Write(authorKey,_G._C.CurTxAddr)
            _G.AppData.Write(versionKey,01)
         else
            local version=_G.AppData.Read(versionKey,01):ToInt()
            _G.AppData.Write(versionKey,version+1)
         end

        _G.AppData.Write(updateKey,_G.mylib.GetTxConFirmHeight())
        _G.AppData.Write(name,{_G.mylib.GetCurTxHash()})
    end
}

_G.LPM={
    Cache={},
    Source={0xbd,0x91,0x01,0x00,0x01,0x00},
    inject=load('_G.import=function(n) return _G.LPM.import(n) end')(),
    import=function(n)
        if _G.LPM.Cache[n] then
            return _G.LPM.Cache[n]
        end
        local d={_G.mylib.GetTxContract(_G.mylib.GetContractData({id=_G.LPM.Source,key=n}))}
        if #d>20 then
            local c=''
            for i=21,#d do
                c=c..string.format('%c',d[i])
            end
            local m=load(c)()
            _G.LPM.Cache[n]=m
            return m
        end
        error(string.format('Module %s not found or source error',n))
    end
}
