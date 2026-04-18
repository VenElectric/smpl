from tables import Table
from streams import Stream
import std/options

type
    ErrorKind* = enum 
        LexError,
        CompileError,
        RuntimeError,
        ArithError,
        TypeError
    SmplError* = object
        msg*: string
        kind*: ErrorKind
    SmplCompiler* = object
        lexer*: SmplLex
        hasError*: bool = false
        currError*: SmplError
        line*: int
    SmplKind* = enum
        SNone,
        SBool,
        SInt,
        SFloat,
        SString,
        STable,
        SList,
        SCall
    SmplInt* = int64
    SmplFloat* = float64
    SmplTable* = Table[string,SmplValue]
    SmplList* = seq[SmplValue]
    SmplNimFn* = proc(state:var SmplState)
    SmplCallable* = object
        name*: string
        case isNimFn*:bool
        of true: fn*: SmplNimFn
        else: code*: SmplNode
    SmplValue* = ref object
        case kind*: SmplKind
            of SNone: discard
            of SBool: boolv*: bool
            of SInt: intv*: SmplInt
            of SFloat: fltv*: SmplFloat
            of SString: strv*: string
            of STable: tabv*: SmplTable
            of SList: lstv*: SmplList
            of SCall: callv*: SmplCallable
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
        of NKInt: intv*: SmplInt
        of NKFloat: fltv*: SmplFloat
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
    SmplState* = object
        words*: SmplTable
        stack*: SmplList
        vars*: SmplTable
        compiler*: SmplCompiler
        errorState*: Option[SmplError]
