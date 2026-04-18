import stypes

func kind*(v:SmplValue): SmplKind = v.kind

proc newSmplValue(kind:SmplKind): SmplValue = SmplValue(kind:kind)

proc newSmplNil*(): SmplValue = newSmplValue(SNone)

proc newSmplBool*(v:bool): SmplValue = 
    result = newSmplValue(SBool)
    result.boolv = v

proc newSmplInt*(v:SmplInt): SmplValue = 
    result = newSmplValue(SInt)
    result.intv = v

proc newSmplFloat*(v:SmplFloat): SmplValue = 
    result = newSmplValue(SFloat)
    result.fltv = v

proc newSmplString*(v:string): SmplValue = 
    result = newSmplValue(SString)
    result.strv = v

proc newSmplCallable*(name:string,v:SmplNode): SmplValue = 
    result = newSmplValue(SCall)
    result.callv = SmplCallable(name:name,isNimFn:false,code:v)

proc newSmplCallable*(name:string,v:SmplNimFn): SmplValue = 
    result = newSmplValue(SCall)
    result.callv = SmplCallable(name:name,isNimFn:true,fn:v)

func isNimFn*(v:SmplValue):bool = v.callv.isNimFn
func isSmplFn*(v:SmplValue): bool = isNimFn(v) == false

proc `$`*(v:SmplValue): string =
    case kind(v)
    of SNone: "nil"
    of SInt: $v.intv
    of SFloat: $v.fltv
    of SBool: $v.boolv
    of SString: v.strv
    else: "todo"