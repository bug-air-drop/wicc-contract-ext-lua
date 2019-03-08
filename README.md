# 合约扩展类Context

------

Context主要由几个子模块组成：

> * HexArray : 核心类, 以面向对象的方式去实现hex数组的管理, 简化了大部分的数组操作
> * AppData : 增删改读合约KV数据库
> * Asset : 对token和wicc的转账操作, 其中wicc只能转移合约本身地址持有的wicc
> * 事件路由 : 管理业务模块和入口方法, 解析contract数据

------

## 初始化

在使用Context任一功能时, 应先初始化Context, 在执行你的代码前, 执行该语句

```lua
_G.Context.Init()
```
这将会映射Context内部的对象到全局上下文中, 如HexArray映射成Hex, 你就可以很简单的实例化一个对象
```lua
local obj=Hex:New({0x61}) -- _G 可以省略, 在代码长度不超过64kb时, 尽量在定义或引用全局变量时, 带上 _G
local obj2=_G.Context.IHexArray:New({0x61}) --不映射时就写比较长
_G.Log('hello')
print(_G._C._Version) --为了方便 Context也映射为一个全局变量 _C
```
当前传入合约调用数据的最佳实践是如下的编码格式:
```
0x01,0x02,...
```
第一个字节描述业务模块, 第二个字节描述该模块的具体业务, 之后的字节数将会保存到 _G.RecvData 这个对象中, 在具体的业务方法中, 只需要对_G.RecvData继续下一步解析. 如果在测试时数据来源是contract, 并希望自动清理掉开头的魔数、模块编号、方法编号等指示具体的业务模块的字节, 你可以
```lua
_G._C.LoadContract()
```
发布到上链的合约代码, 应由Context.Main方法去控制代码的入口, 也就不需要再执行Init和LoadContract:
```lua
_G.Context.Init(_G.BizUnit).Main()
```
放置在合约代码最后一行并作为唯一入口, Context将会去注册你的业务模块, 解析contract, 并调用对应业务方法

## HexArray的使用
HexArray是基于table的, 和table是一样的结构, 不过, 重定向了部分元方法

### 1. New
实例化一个HexArray对象
```lua
local strtable=Hex:New({0x61,0x62}) --可以是字符串转化后的byte
print(strtable) --ab

local str=Hex:New('ab') --也可以直接传入字符串
print(str[1]) --0x61

local int=Hex:New({0x01,0x00}) --如果是数值的bytes
print(int:ToInt()) -- 1
print(int:ToUInt()) -- 1
```
### 2. Equals
判断两个数组是否相等
```lua
local txs  = Hex:New({0x61,0x61})
local txs2 = Hex:New({0x61,0x61})
print(txs==txs2)
print(txs~=txs2)
```
### 3. ToString()
```lua
local strtable=Hex:New({0x61,0x62})
print(strtable) --ab
print(strtable..{0x63,0x64}) --abcd
print(strtable..'cd') --abcd
```
对于连接符 .. LUA会强制将右边转换为string类型再进行连接操作
### 4. ToInt()
转换为数值时, 会调用mylib的ByteToInteger方法去实现. 支持1~8位的字节转换. 少于4字节时, 会在末尾补满0x00到4位再进行转换. 同理, 大于4字节又少于8字节时, 会在末尾补满0x00到8位再进行转换. 
注意: HexArray没有去实现运算符 + - * / 等数学运算, 所有的运算操作应先ToInt()
```lua
local int=Hex:New({0x01,0x00})
print(int:ToInt()) -- 1
local int=Hex:New({0x01,0x00,0x00})
print(int:ToInt()) -- 1
```
### 5. ToUInt()
与平常uint类型的不同的是: 该方法只是对ToInt的值的再校验, 当实际数值小于0时会抛出异常.
所以仅是方便对传入数值的合法性校验, 比如: 转账金额
```lua
local int=Hex:New({0xff,0xff,0xff,0xff})
print(int:ToInt()) -- 输出 -1
print(int:ToUInt()) -- 提示异常, 合约中断
```
### 6. Appand(table)
将一个table的内容追加到末尾
```lua
local source=Hex:New({0x61,0x62})
source:Appand({0x63,0x64})
print(source) --abcd
```
### 7. Embed(index,table)
修改指定位置的内容/填充table到指定位置
```lua
local source=Hex:New({0x61,0x62})
source:Embed(2,{0x63,0x64}) --{0x61,0x63,0x64}, 0x62被0x63覆盖, 接着增加0x64
print(source) --acd
```
当指定索引之后没有足够的长度填充数据时, 将会拓长原数组的长度
### 8. Select(index,lenght)
取出指定位置开始的一定长度的数组, 这将返回一个新的对象
```lua
local source=Hex:New({0x61,0x62,0x63,0x64,0x65})
local select=source:Select(2,3) --{0x62,0x63,0x64}
print(select) --bcd
```
### 9. Take(lenght)
取出从位置1开始的一定长度的数组, 这将返回一个新的对象
```lua
local source=Hex:New({0x61,0x62,0x63,0x64,0x65})
local take=source:Take(2) --{0x61,0x62}
print(take) --ab
```
### 10. Skip(lenght)
跳过指定长度, 返回剩余的全部字节的数组, 这将返回一个新的对象
```lua
local source=Hex:New({0x61,0x62,0x63,0x64,0x65})
local skip=source:Skip(2) --{0x63,0x64,0x65}
print(skip) --cde
```
### 11. Next(lenght)
在每个HexArray对象内部都维护一个数值Posit, 指示当前读取到的位置, 在大部分业务中都是逐字节向前读取解析的, 所以该方法可以很方便地获取想要的业务数据
```lua
local source=Hex:New({0x61,0x62,0x63,0x64,  0x02,0x00,0x00,0x00,  0x61,0x61,0x61, 0x00})
local from=source:Next(4):ToString() -- {0x61,0x62,0x63,0x64} = abcd
local money=source:Next(4):ToUInt() -- {0x02,0x00,0x00,0x00} = 2
local to=source:Next(3):ToString() -- {0x61,0x61,0x61} = aaa
print(from..' send '..money..' wicc to '..to)
```
当尝试获取的长度超过数组本身的长度时, 会抛出错误.
### 12. Fill(template)
将字节数据按给定的模板填充到table, 如下:

*例1: 字符串解析*

```lua
local source=Hex:New({0x61,0x62})
local model=source:Fill({"a","2"})
print(model.a) --ab
```
该例中, {0x61,0x62}为编码后的元数据, {"a","2"}为模板
```
{
    "a",   -- Key的名称
    "2",   -- 描述Value的数据类型为string, 长度为2
}
```
可以描述的数据类型有number, string 和 table.

*例2: 数值解析*

```lua
local source=Hex:New({0x61,0x62,0x01})
local model=source:Fill({"a","2","b",1})
print(model.a) --ab
print(model.b) --1
```
模板结构解析:
```
{
    "a",   -- Key的名称
    "2",   -- 描述Value的数据类型为string, 长度为2
    "b",
     1     --数值类型为number, 长度为1
}
```
**如上, Key-Value总是成对出现的, 并会按Key-Value出现的顺序去解析填充数据**

*例3: 嵌套*

模板是支持多个层级结构的

```lua
local source=Hex:New({0x61,0x62,0x01})
local model=source:Fill({"a","2","sub",{Len=1,"int",1}})
print(model.a) --ab
print(model.sub.int) --1
```
模板结构解析:
```
{
    "a",   -- Key的名称
    "2",   -- 描述Value的数据类型为string, 长度为2
    "sub",
     {     -- sub的Value类型为table
        Len=1,  -- Len描述了子模板全部数据的字节长度
        "int",
          1
     }
}
```

*例4: 集合/数组*

描述接下来的一段数据是可以组成一个集合的

```lua
local source=Hex:New({0x61,0x62,0x63,0x64,0x65})
local model=source:Fill({"objs",{Loop=3,Len=1,Model={"name","1"}}})
for i=1, #model.objs do
    print(model.objs[i].name)
end
```
模板结构解析:
```
{
    "objs",   -- Key的名称
     {     -- Value类型为table
        Loop=3, -- 描述数据类型是一个集合, 需要循环3次
        Len=1,  -- Len描述了子模板全部数据的字节长度, 也就是Model中模板长度
        Model={ -- 给出了一个模板, 用于解析每个片段的字节
            "name",
              "1"
        }
     }
}
```
实际解析过程是这样的, 解析到objs时, 知道objs对应的value是一个table, 并了解到objs是一个集合, 于是, 
step1 先Next(Loop*Len)的长度出来{0x61,0x62,0x63}  
step2 将这块数据分成3份 {0x61} {0x62} {0x63} 
step3 将每一份按模板{"name","1"}再去解析
展开结构:
```lua
{
    objs={
        {
            name="a"
        },
        {
            name="b"
        },
        {
            name="c"
        },
    }
}
```
至于后面的两个字节 0x64,0x65 就不再解析了; 如果Loop=0, 表示循环读取直到元数据结尾, 那么objs的就有5个对象了

*例5: 无意义/占位/不解析*

当是一个循环模板时, 并且不指定Model, 例3上面的结构会变成:
```lua
{
    objs={
        {
            0x61
        },
        {
            0x62
        },
        {
            0x63
        },
    }
}
```
即不会解析. 也等同于模板 {"objs",{Loop=3,Len=1,Model={1}}}
你可以使用 {i} 去存储你不想解析的数据

*例6: 补充示例*

```lua
--批量转账
local source=Hex:New({0x61,0x61,0x01,0x00,0x62,0x62,0x02,0x00,0x63,0x63,0x03,0x00})
local bills=source:Fill({Loop=3,Len=4,Model={"name","2","money",2}})
for i=1, #bills do
    sendMoney(bills[i].name,bills[i].money)
    print(bills[i].name..' get money='..bills[i].money)
end
```

当业务数据比较复杂时, 即集合的数量是不固定的, 且有不同业务意义的多个集合, 那么你可以在编码时将集合的数量一并写入
```lua
--批量转账2
local source=Hex:New({0x03,0x61,0x61,0x01,0x00,0x62,0x62,0x02,0x00,0x63,0x63,0x03,0x00})
local bills=source:Fill({Loop=-1,Len=4,Model={"name","2","money",2}})
for i=1, #bills do
    sendMoney(bills[i].name,bills[i].money)
    print(bills[i].name..' get money='..bills[i].money)
end
```
此时, Loop是一个负值, 表示开始的多少个字节的意义表示集合的总数, 此处为 {0x03}, 转换后为3.

```lua
--批量转账和扣款
local source=Hex:New({0x02, 0x61,0x61,0x01,0x00,0x62,0x62,0x02,0x00, 0x01, 0x63,0x63,0x03,0x00})
local addMoney=source:Fill({Loop=-1,Len=4,Model={"name","2","money",2}})
for i=1, #addMoney do
    AddMoney(addMoney[i].name,addMoney[i].money)
    print(addMoney[i].name..' add money='..addMoney[i].money)
end
local subMoney=source:Fill({Loop=-1,Len=4,Model={"name","2","money",2}})
for i=1, #subMoney do
    SubMoney(subMoney[i].name,subMoney[i].money)
    print(subMoney[i].name..' sub money='..subMoney[i].money)
end
```
也可以用一个模板把数据一次性解析出来
```lua
--批量转账和扣款
local source=Hex:New({0x02, 0x61,0x61,0x01,0x00,0x62,0x62,0x02,0x00, 0x01, 0x63,0x63,0x03,0x00})
local model=source:Fill(
                            {
                            "addList",{Loop=-1,Len=4,Model={"name","2","money",2}},
                            "subList",{Loop=-1,Len=4,Model={"name","2","money",2}}
                            }
                       )
                       
for i=1, #model.addList do
    AddMoney(model.addList[i].name,model.addList[i].money)
    print(model.addList[i].name..' add money='..model.addList[i].money)
end

for i=1, #model.subList do
    SubMoney(model.subList[i].name,model.subList[i].money)
    print(model.subList[i].name..' sub money='..model.subList[i].money)
end
```

## AppData的使用

实现了对合约键值对数据库的操作
(略)

## Asset的使用

### 1. SendSelfNetAsset(toAddr, money)
将合约本身地址持有的wicc转移到指定地址
```lua
Asset.SendSelfNetAsset('wYZ4tMQ7w2G3j3a2krJAg4HmM9PNrfmuBH',1000) -- 1 wicc= 100000000
```
(Asset中转账的操作, 不建议使用regid去转账)

### 2. GetNetAsset(address)
获取指定地址的wicc余额

### 3. GetAppAsset(address)
获取指定地址的持有的当前合约的token数量

### 4. AddAppAsset(address,money)
增加指定地址的当前合约的token数量

### 5. SubAppAsset(address,money)
减少指定地址的当前合约的token数量, 减少时会检查该地址当前的token余额, 不足时抛出异常

### 6. SendAppAsset(from,to,money)
从一个账户转移一定数量的token到另外一个账户, 如发送方持有的token数量不住会抛出异常


综上, Asset实现了常见的资金操作, 并会对金额进行校验.

## 注册业务模块
编写合约代码时, 建议将业务统一封装, 如ContextTestUnit这个测试用例模块.

Context.Init(...) 方法会检查你传入的table是否有Init方法, 有则执行. 
```lua
_G.ContextTestUnit={
    Init=function()
        _G._C.Event[0xaa]=_G.ContextTestUnit                        --将_G._C.Event的0xaa位置指向_G.ContextTestUnit
        _G.ContextTestUnit[0xbb]=_G.ContextTestUnit.HexArrayTest    --将ContextTestUnit的0xbb位置指向内部的一个方法
        ...
        ...
    end,
    HexArrayTest=function()
        ...
    end
}

_G.Context.Init(_G.ContextTestUnit).Main()
```
当你调用合约传入参数的开头是  0xaa,0xbb,...  时, 就会直接调用_G.ContextTestUnit.HexArrayTest这个方法, 具体的加载逻辑可以查看Context.Main这个方法. 

## 本地调试

为了方便引用Context的代码, 就将内部的方法完整的包裹进table, 在单独调试代码时, 比如测试数据的解析情况就需要自由地执行代码, 你可以在执行你的代码前, 执行一些代码, 参见开头的章节. 代码类似如下:

```lua
mylib = require "mylib"

_G.Context = {
    ...
}

_G.Context.Init()  --你就可以使用Context的大部分功能了

contract={0x61,0x62}
print(Hex:New(contract))

```

### 异常模块 ErrExt

ErrExt是对可选的模块, 当你不添加这个模块时, Context报出的异常只有简短的错误代码(code)编号, 但你仍然可以结合coind返回的错误行号去定位具体的代码

{"code":"404"}

添加ErrExt后, 你就可以获得更多的错误信息:

{"code":"404","msg":"domain or method not found, call:153"}

msg中的信息, 就是在ErrExt中配置. 也可以直接写入.

```lua
_G.ErrExt[888]='这是一条自定义错误描述信息, %s'
assert(1>1 or _G._err(888,'没有说明'),_G._errmsg) --使用这个格式去做断言, 使用自定义错误内容的同时仍得到正确的错误行号信息
```



