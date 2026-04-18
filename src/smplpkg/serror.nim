import std/strformat
from stypes import ErrorKind,SmplError

func newSmplError(msg,what,where:string,kind:ErrorKind): SmplError = 
    result.msg = fmt"[{what}:{where}] {msg}"
    result.kind = kind

func newLexError*(msg,what,where:string): SmplError = newSmplError(msg,what,where,LexError)

func newCompileError*(msg,what,where:string): SmplError = newSmplError(msg,what,where,CompileError)

func newRuntimeError*(msg,what,where:string): SmplError = newSmplError(msg,what,where,RuntimeError)

func newArithError*(msg,what,where:string): SmplError = newSmplError(msg,what,where,ArithError)

func newTypeError*(msg,what,where:string): SmplError = newSmplError(msg,what,where,TypeError)
