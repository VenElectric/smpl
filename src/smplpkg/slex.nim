import std/[streams,strutils]
from algorithm import reverse

type
    TokenKind* = enum
        TBool,
        TInt,
        TFloat,
        TString,
        TIdent,
        TFunc,
        TIf,
        TElse,
        TLoop,
        TDo,
        TAssign,
        TMatch,
        TIs,
        TEnd,
        TError
    TokenPart* = object
        part*: string
        line*: uint
        kind*: TokenKind
    SmplLex* = object
        eof: bool = false
        cursor: int = 0
        line: uint
        buff: Stream

using
    s:SmplLex
    vs: var SmplLex

# proc lexError*(vs;msg:string) = 
#     vs.hasError = true
#     vs.currError = newLexError(msg,"Lexer",$vs.line)

proc LexloadFile*(file_name: string): SmplLex =
    result.buff = openFileStream(file_name, fmRead)
    result.line = 1

proc LexloadString*(str: string): SmplLex =
    result.buff = newStringStream(str)
    result.line = 1

proc close*(vs) = close(vs.buff)


proc atEnd*(s): bool = atEnd(s.buff)

func createToken(part: string, line: uint, kind: TokenKind): TokenPart =
    result.part = part
    result.line = line
    result.kind = kind

proc isInt(part: string): bool =
    result = false
    if len(part) == 0:
        return
    for p in part:
        if not isDigit(p):
            return
    result = true
proc isFloat(part: string): bool =
    result = false
    if len(part) == 0:
        return
    let spl = split(part,'.')
    if len(spl) == 2:
        if isInt(spl[0]) and isInt(spl[1]):
            result = true

func isBool(part: string): bool = part == "true" or part == "false"

proc getIdentKind(part: string): TokenKind =
    case part
    of "fn":
        result = TFunc
    of "if":
        result = TIf
    of "else":
        result = TElse
    of "match":
        result = TMatch
    of "is":
        result = TIs
    of "end":
        result = TEnd
    of "loop":
        result = TLoop
    of ":=":
        result = TAssign
    of "do":
        result = TDo
    else:
        result = TIdent # will be caught in compile if it's not a valid word or var

proc getLine(vs): string = readLine(vs.buff)

# differentiate between starting " and ending "
# @["123", ""hello","new", "world""]
# sPos = 1
# we want to skip that
# sPos+1 to 3  2..3
# then collection line[1..3]
proc parseString(vs;line: seq[string], dest:var string): int =
    result = 0
    let sPos = vs.cursor
    var ePos = -1
    for idx in sPos..high(line):
        let p = line[idx]
        if endsWith(p,'"'):
            ePos = idx
            break
    if sPos == ePos:
        dest = line[vs.cursor]
        result = 1
    elif ePos > -1: 
        dest = join(line[sPos..ePos]," ")
        result = ePos - sPos
    

    
        
        

proc getTokenKind(part: string): TokenKind =

    if isBool(part):
        result = TBool
    elif isInt(part):
        result = TInt
    elif isFloat(part):
        result = TFloat
    else:
        result = getIdentKind(part)


proc parseLine(vs): seq[TokenPart] =

    let line = split(strip(getLine(vs)), ' ')
    vs.cursor = 0
    while true:
        if vs.cursor >= len(line):
            break
        var part:string
        var kind: TokenKind
        if startswith(line[vs.cursor], '"'):
            let parsed = parseString(vs,line, part)
            if parsed > 0:
                inc(vs.cursor,parsed)
                kind = TString
            else:
                kind = TError
                part = "Unterminated string"
        else:
            part = line[vs.cursor]
            kind = getTokenKind(part)
            inc(vs.cursor)

        result.add createToken(part, vs.line, kind)

proc next*(vs): seq[TokenPart] =
    if atEnd(vs):
        return

    result = parseLine(vs)
    reverse(result)
    inc(vs.line)

