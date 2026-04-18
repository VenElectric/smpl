import std/[options,strutils]
import slex

type
    NodeKind* = enum 
        NKInt,
        NKFloat,
        NKString,
        NKBool,
        NKList,
        NKIdent, # to be determined by state
        NKAssign,
        NKMatch,
        NKLoop,
        NKBranch,
        NKIfElse,
        NKFnDef,
        NKDo, # line
        NKStmts # file
    SmplAssign* = object
        key*: string
        value*:SmplNode
    SmplNode* = ref object
        case kind*:NodeKind
        of NKInt: intv*: int64
        of NKFloat: fltv*: float64
        of NKBool: boolv*: bool
        of NKString: strv*: string
        of NKIdent: ident*: string
        of NKAssign: assign*: SmplAssign
        of NKMatch: 
            condIdent*: string
            isStmts*: SmplNode # NKStmts
        of NKIfElse: 
            ifStmt*: SmplNode
            elseStmt*: SmplNode
        of NKBranch,NKLoop: 
            cond*: SmplNode
            body*: SmplNode
        of NKStmts,NKDo: nodes*: seq[SmplNode]
        of NKFnDef: 
            name*: string
            code*: SmplNode
        of NKList:
            listName*: string
            values*: seq[SmplNode]

using 
    vs: var SmplLex


proc newSmplNode(kind:NodeKind): SmplNode = result = SmplNode(kind:kind)

proc newIdentNode(ident:string): SmplNode =
    result = newSmplNode(NKIdent)
    result.ident = ident

proc add(s:var SmplNode,v:SmplNode) = 
    assert(s.kind in {NKStmts,NKDo},"Invalid kind: " & $s.kind)
    s.nodes.add v 

func kind*(node:SmplNode): NodeKind = node.kind

iterator nodes*(stmts:SmplNode): SmplNode = 
    for node in stmts.nodes:
        yield node

proc newLit(v:bool): SmplNode = 
    result = newSmplNode(NKBool)
    result.boolv = v

proc newLit(v:int64): SmplNode = 
    result = newSmplNode(NKInt)
    result.intv = v

proc newLit(v:float64): SmplNode = 
    result = newSmplNode(NKFloat)
    result.fltv = v


proc newLit(v:string): SmplNode = 
    result = newSmplNode(NKString)
    result.strv = v

proc newSmplDo(): SmplNode = newSmplNode(NKDo)

proc newSmplStmts(): SmplNode = newSmplNode(NKStmts)



proc newSmplLoop(): SmplNode =
    result = newSmplNode(NKLoop)
    result.cond = newSmplDo()
    result.body = newSmplDo()

proc newBranchNode(): SmplNode =
    result = newSmplNode(NKBranch)
    result.cond = newSmplDo()
    result.body = newSmplDo()

proc newIfElseStmt(): SmplNode =
    result = newSmplNode(NKIfElse)

proc newFnDefNode(name:string): SmplNode =
    result = newSmplNode(NKFnDef)
    result.name = name
    result.code = newSmplDo()

proc newAssignNode(key:string): SmplNode =
    result = newSmplNode(NKAssign)
    result.assign = SmplAssign(key:key)

proc newMatchNode(condIdent:string): SmplNode =
    result = newSmplNode(NKMatch)
    result.condIdent = condIdent
    result.isStmts = newSmplStmts()

const PrimitiveTokens = {TFloat,TInt,TBool,TString}

proc check(vc;kind:TokenKind): bool =
    result = false
    if isSome(peek(vc)):
        let tk = get(peek(vc))
        result = tk.kind == kind

proc check(vc;kind:set[TokenKind]): bool =
    result = false
    let opt = peek(vc)
    if isSome(opt):
        let tk = get(opt)
        result = tk.kind in kind

proc skip(vc) = discard pop(vc)

proc consume(vc;kind:TokenKind,msg:string) = 
    if check(vc,kind):
        skip(vc)
    else:
        compileError(vc,msg)

proc expect(vc;kind:TokenKind,msg:string) = 
    if not check(vc,kind):
        compileError(vc,msg)

proc expect(vc;kind:set[TokenKind],msg:string) = 
    if not check(vc,kind):
        compileError(vc,msg)



proc EOL(vc): bool = isNone(peek(vc))



proc eolError(vc;msg:string) = 
    if EOL(vc):
        compileError(vc,msg)

proc compile_line(vc): SmplNode
proc compile_token(vc): SmplNode
proc compile_until(vc;kind:TokenKind): SmplNode
proc compile_until(vc;kind:set[TokenKind]): SmplNode

proc compile_fndef(vc): SmplNode = 
    skip(vc)
    expect(vc,TIdent,"Expect ident for function name")
    let name = pop(vc)
    eolError(vc,"Incomplete function definition")
    echo "eol: ",EOL(vc)
    result = newFnDefNode(get(name).part)
    result.code = compile_line(vc)

proc compile_ifelse(vc): SmplNode =
    skip(vc)
    result = newIfElseStmt()
    result.ifStmt = newBranchNode()
    result.ifStmt.cond = compile_until(vc,TDo)
    eolError(vc,"Incomplete if/else statement")
    consume(vc,TDo,"Do required after if condition")
    result.ifStmt.body = compile_until(vc,{TElse,TEnd})
    if check(vc,TElse):
        result.elseStmt = newBranchNode()
        skip(vc) #Telse
        result.elseStmt.cond = newLit(true)
        result.elseStmt.body = compile_until(vc,TEnd)
    consume(vc,TEnd,"Unterminated if statement")
    

proc compile_match(vc): SmplNode = 
    skip(vc)
    eolError(vc,"Expect condition for match statement")
    let cond = pop(vc)
    result = newMatchNode(get(cond).part)
    if not EOL(vc):
        compileError(vc,"Is Branches must be on separate lines")
    next(vc)
    expect(vc,TIs,"Match statements must have is statements")

    while check(vc,TIs) and not errorCheck(vc):
        consume(vc,TIs,"Expect Is before is statement")
        var branch = newBranchNode()
        branch.cond = compile_token(vc)
        consume(vc,TDo,"Expect do after branch condition")
        branch.body = compile_line(vc)
        add(result.isStmts,branch)
        next(vc)
    consume(vc,TEnd,"Unterminated match statement")

proc compile_assign(vc): SmplNode = 
    skip(vc)
    expect(vc,TIdent,"Expected ident")
    eolError(vc,"Expect ident and not EOL")
    let ident = pop(vc)
    result = newAssignNode(get(ident).part)
    eolError(vc,"Expect expression after ident")
    result.assign.value = compile_line(vc)

proc compile_loop(vc): SmplNode = 
    skip(vc) #TLoop
    result = newSmplLoop()
    result.cond = compile_until(vc,TDo)
    eolError(vc,"Unfinished loop statement")
    consume(vc,TDo,"Loop condition must be followed by Do statement")
    result.body = compile_line(vc)

proc compile_primitive(vc;tk:TokenPart): SmplNode = 
    let kind = tk.kind
    let part = tk.part
    case kind:
    of TBool:
        result = newLit(parseBool(part))
    of TInt:
        result = newLit(parseBiggestInt(part))
    of TFloat:
        result = newLit(parseFloat(part))
    of TString:
        result = newLit(part)
    else:
        compileError(vc,"Invalid kind for primitive: " & $kind) #unreachable

proc compile_token(vc): SmplNode =    
    eolError(vc,"Expect token and not EOL")
    expect(vc,PrimitiveTokens + {TIdent},"Compile Token must compile a primitive or ident")
    let tk = get(pop(vc))
    let part = tk.part
    let kind = tk.kind
    case kind:
    of PrimitiveTokens: result = compile_primitive(vc,tk)
    of TIdent: result = newIdentNode(part)
    else: discard


proc compile_until(vc;kind:set[TokenKind]): SmplNode = 
    result = newSmplDo()
    while not check(vc,kind) and not EOL(vc) and not errorCheck(vc):
        add(result,compile_token(vc))

proc compile_until(vc;kind:TokenKind): SmplNode = 
    result = newSmplDo()
    while not check(vc,kind) and not EOL(vc) and not errorCheck(vc):
        add(result,compile_token(vc))

proc compile_line(vs;line:seq[TokenPart]): SmplNode = 
    if vc.hasError:
        return
    eolError(vc,"Expect token and not EOL")
    result = newSmplDo()
    while not EOL(vc) and not errorCheck(vc):
        let tk = get(peek(vc))
        let kind = tk.kind
        case kind:
            of PrimitiveTokens,TIdent,TEnd: 
                add(result,compile_token(vc))
            of TFunc:
                add(result,compile_fndef(vc))
            of TAssign:
                add(result,compile_assign(vc))
            of TLoop:
                add(result,compile_loop(vc))
            of TIf:
                add(result,compile_ifelse(vc))
            of TIs:
                skip(vc)
                add(result,compile_line(vc))
            of TElse:
                compileError(vc,"If/Else Statements must be on the same line")
            else:
                compileError(vc,"Invalid Kind // Unreachable" & $kind)



proc compile_block(vs): SmplNode = 
    result = newSmplStmts()

    while not atEnd(vs):
       
        next(vs)
        let tk = peek(vs)
        if isSome(tk):
            let kind = get(tk).kind
            case kind:
            of TMatch:
                add(result,compile_match(vc))
            of TFunc,TAssign,TLoop,PrimitiveTokens,TIdent,TIf:
                add(result,compile_line(vc))
            of TDo,TIs,TElse,TEnd:
                compileError(vc,"Kind should not be a top level statement: " & $get(tk).kind)
        else:
            compileError(vc,"Empty file")

proc loadFile*(file:string):SmplCompiler = 
    result.lexer = LexloadFile(file)
proc loadString*(buff:string):SmplCompiler = 
    result.lexer = LexloadString(buff)

proc compile*(vs): SmplNode = 
    defer: close(vs)
    if atEnd(vs):
        return
    
    result = compile_block(vs)


