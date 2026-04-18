import std/tables
import stypes,scompile,svalue

using
    vstate: var SmplState

proc execute_file*(file:string)
proc execute_file*(vstate;file:string)

func hasCompilerError(vstate): bool = vstate.compiler.hasError
func hasLexerError(vstate): bool = vstate.compiler.lexer.hasError

proc listEQ(one,two:SmplList): bool

proc `==`(l,r:SmplValue): bool =
    if kind(l) != kind(r):
        return false
    case kind(l):
    of SInt: result = l.intv == r.intv
    of SFloat: result = l.fltv == r.fltv
    of SBool: result = l.boolv == r.boolv
    of SString: result = l.strv == r.strv
    of STable: result = l.tabv == r.tabv
    of SList: 
        result = listEQ(l.lstv,r.lstv)
    of SCall: 
        if (isNimFn(l) and isNimFn(r)) or (isSmplFn(l) and isSmplFn(r)):
            result = l.callv.name == r.callv.name
        else:
            result = false
    of SNone: result = true

proc listEQ(one,two:SmplList): bool = 
    result = len(one) == len(two)
    if result == true:
        for idx in countup(0,high(one)):
            result = one[idx] == two[idx]

proc `>=`(l,r:SmplValue): bool = 
    if kind(l) != kind(r):
        return false
    case kind(l):
    of SInt: result = l.intv >= r.intv
    of SFloat: result = l.fltv >= r.fltv
    else: result = false 

proc `>`(l,r:SmplValue): bool = 
    if kind(l) != kind(r):
        return false
    case kind(l):
    of SInt: result = l.intv > r.intv
    of SFloat: result = l.fltv > r.fltv
    else: result = false     

proc `<=`(l,r:SmplValue): bool = 
    if kind(l) != kind(r):
        return false
    case kind(l):
    of SInt: result = l.intv <= r.intv
    of SFloat: result = l.fltv <= r.fltv
    else: result = false 

proc `<`(l,r:SmplValue): bool = 
    if kind(l) != kind(r):
        return false
    case kind(l):
    of SInt: result = l.intv < r.intv
    of SFloat: result = l.fltv < r.fltv
    else: result = false 



proc push*(vstate;v:SmplValue) = vstate.stack.add v
proc pop*(vstate): SmplValue = 
    assert(len(vstate.stack) > 0,"Stack underflow")
    vstate.stack.pop()
proc peek*(vstate): SmplValue = 
    assert(len(vstate.stack) > 0,"Stack underflow")
    vstate.stack[^1]


proc hasWord*(vstate;key:string): bool = hasKey(vstate.words,key)

proc setWord*(vstate;v:SmplValue) = 
    assert(kind(v) == SCall,"Kind can not be a word: " & $kind(v))
    let key = v.callv.name
    vstate.words[key] = v

proc setWord*(vstate;name:string,v:SmplNimFn) = 
    setWord(vstate,newSmplCallable(name,v))

proc getWord*(vstate;key:string): SmplValue = vstate.words[key]

proc hasVar*(vstate;key:string): bool = hasKey(vstate.vars,key)

proc setVar*(vstate;key:string,v:SmplValue) = vstate.vars[key] = v
proc getVar*(vstate;key:string): SmplValue = vstate.vars[key]

proc binop_pop(vstate): tuple[l,r:SmplValue] =
    let r = pop(vstate)
    let l = pop(vstate)
    result = (l:l,r:r)

proc wadd(vstate){.sideEffect.} = 
    let (l,r) = binop_pop(vstate)
    if kind(l) == SInt and kind(r) == SInt:
        push(vstate,newSmplInt(l.intv + r.intv))
    elif kind(l) == SFloat and kind(r) == SFloat:
        push(vstate,newSmplFloat(l.fltv + r.fltv))
    else:
        assert(false,"TODO")

proc wmin(vstate){.sideEffect.} = 
    let (l,r) = binop_pop(vstate)
    if kind(l) == SInt and kind(r) == SInt:
        push(vstate,newSmplInt(l.intv - r.intv))
    elif kind(l) == SFloat and kind(r) == SFloat:
        push(vstate,newSmplFloat(l.fltv - r.fltv))
    else:
        assert(false,"TODO")

proc wprint(vstate){.sideEffect.} = 
    # assert(len(vstate.stack) > 0)
    for v in vstate.stack:
        echo $v

 # should raise for values that are not SInt and SFloat
proc wge(vstate) {.sideEffect.} = 
    let (l,r) = binop_pop(vstate)
    push(vstate,newSmplBool(l >= r)) 
   

proc wgreater(vstate) {.sideEffect.} = 
    let (l,r) = binop_pop(vstate)
    push(vstate,newSmplBool(l > r))

proc wle(vstate) {.sideEffect.} = 
    let (l,r) = binop_pop(vstate)
    push(vstate,newSmplBool(l <= r)) 
   

proc wless(vstate) {.sideEffect.} = 
    let (l,r) = binop_pop(vstate)
    push(vstate,newSmplBool(l < r))

# 
proc wimport(vstate) {.sideEffect.} = 
    let file = pop(vstate)
    assert(kind(file) == SString,"Must have a valid file string identifier")
    vstate.compiler = loadFile(file.strv)
    let code = compile(vstate.compiler)
    push(vstate,newSmplCallable(file.strv,code))

proc wexecute(vstate) {.sideEffect.} = 
    let file = pop(vstate)
    assert(kind(file) == SString,"Must have a valid file string identifier")
    execute_file(vstate,file.strv)

let words: seq[(string,SmplNimFn)] = @[("+",wadd),("-",wmin),(">=",wge),(".",wprint),(">",wgreater),
            ("<=",wle),("<",wless),("import",wimport),("exec",wexecute)]

proc newState*(): SmplState = 
    result = SmplState()
    for w in words:
        let (key,fn) = w
        setWord(result,key,fn)
    result.stack = @[]




# newSmplTable?
# newSmplList?


const PrimitiveNodes = {NKInt,NKFloat,NKString,NKBool}


proc truthy(v:SmplValue): bool =
    case kind(v):
    of SNone: result = false
    of SBool: result = v.boolv
    else: result = true

proc execute_do(vstate;node:SmplNode)
proc execute_stmts(vstate;node:SmplNode)

proc execute_call(vstate;v:SmplCallable) = 
    if v.isNimFn:
        v.fn(vstate)
    else:
        execute_stmts(vstate,v.code)

proc execute_value(vstate;v:SmplValue) = 
    case kind(v):
    of SNone,SBool,SInt,SFloat,SString,STable,SList:
        push(vstate,v)
    of SCall:
        execute_call(vstate,v.callv)

proc execute_lit(vstate;node:SmplNode) = 
    assert(kind(node) in PrimitiveNodes)
    var v: SmplValue
    case kind(node):
    of NKInt: v = newSmplInt(node.intv)
    of NKFloat: v = newSmplFloat(node.fltv)
    of NKString: v = newSmplString(node.strv)
    of NKBool: v = newSmplBool(node.boolv)
    else: assert(false,"Invalid Kind") # unreachable

    execute_value(vstate,v)


proc execute_ident(vstate;node:SmplNode) =
    assert(kind(node) == NKIdent)
    var v:SmplValue
    let key = node.ident
    if hasWord(vstate,key):
        v = getWord(vstate,key)
    elif hasVar(vstate,key):
        v = getVar(vstate,key)
    else:
        v = newSmplNil()
    execute_value(vstate,v)

proc execute_assign(vstate;node:SmplNode) = 
    assert(kind(node) == NKAssign)
    let key = node.assign.key
    let value = node.assign.value
    execute_do(vstate,value)
    setVar(vstate,key,pop(vstate)) # value to assign should be on top of stack

proc execute_match(vstate;node:SmplNode) = 
    assert(kind(node) == NKMatch)
    let ident = node.condIdent
    let v = getVar(vstate,ident)
    for b in nodes(node.isStmts):
        assert(kind(b) == NKBranch)
        let cond = b.cond
        if kind(cond) in PrimitiveNodes:
            execute_lit(vstate,cond)
        elif kind(cond) == NKIdent:
            execute_ident(vstate,cond)
        let res = pop(vstate)
        if v == res:
            execute_do(vstate,b.body)
            break

proc execute_ifelse(vstate;node:SmplNode) = 
    assert(kind(node)==NKIfElse)
    let ifStmt = node.ifStmt
    let elseStmt = node.elseStmt
    execute_do(vstate,ifStmt.cond)
    let v = pop(vstate)
    assert(kind(v) == SBool,"Invalid Kind: " & $kind(v)) # Runtime Error
    if v.boolv:
        execute_do(vstate,ifStmt.body)
    else:
        if not isNil(elseStmt):
            execute_do(vstate,elseStmt.body)
        
proc execute_loop(vstate;node:SmplNode) = 
    assert(kind(node) == NKLoop)
    let cond = node.cond
    let body = node.body
    execute_do(vstate,cond)
    
    while truthy(pop(vstate)):
        execute_do(vstate,body)
        execute_do(vstate,cond)


proc execute_fndef(vstate;node:SmplNode) = 
    assert(kind(node) == NKFnDef)
    setWord(vstate,newSmplCallable(node.name,node.code))

proc execute_do(vstate;node:SmplNode) = 
    assert(kind(node) == NKDo,"Must execute do stmt")
    for n in nodes(node):
        case kind(n):
        of PrimitiveNodes: execute_lit(vstate,n)
        of NKIdent: execute_ident(vstate,n)
        of NKAssign: execute_assign(vstate,n)
        of NKIfElse: execute_ifelse(vstate,n)
        of NKLoop: execute_loop(vstate,n)
        of NKDo: execute_do(vstate,n) # I'm not even sure about this one
        of NKFnDef: execute_fndef(vstate,n)
        else: discard #stmt and fndef should not be here

proc execute_stmts(vstate;node:SmplNode) = 
    assert(kind(node) == NKStmts,"Cannot execute non-stmt")
    for n in nodes(node):
        case kind(n):
        of PrimitiveNodes: execute_lit(vstate,n)
        of NKIdent: execute_ident(vstate,n)
        of NKAssign: execute_assign(vstate,n)
        of NKMatch: execute_match(vstate,n)
        of NKIfElse: execute_ifelse(vstate,n)
        of NKLoop: execute_loop(vstate,n)
        of NKDo: execute_do(vstate,n)
        of NKFnDef: execute_fndef(vstate,n)
        else: discard # branch only valid in ifelse and match???? stmts should only be root...

proc execute_file*(file:string) = 
    var s = newState()
    s.compiler = loadFile(file)
    let code = compile(s.compiler)
    
    if hasCompilerError(s):
        echo s.compiler.currError.msg
        return
    if hasLexerError(s):
        echo s.compiler.lexer.currError.msg
        return
    execute_stmts(s,code)

proc execute_file*(vstate;file:string) = 
    vstate.compiler = loadFile(file)
    let code = compile(vstate.compiler)
    if hasCompilerError(vstate):
        echo vstate.compiler.currError.msg
        return
    if hasLexerError(vstate):
        echo vstate.compiler.lexer.currError.msg
        return
    execute_stmts(vstate,code)