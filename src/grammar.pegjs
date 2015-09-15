{// Begin preamble
  var p = {}

  function transformArgs (args) {
    var head = args[0], tail = args[2]
    return [head].concat(tail.map(function (ti) {
      return ti[2]
    }))
  }

  // p.setPosition = function (line, column) {
  //   this.line   = line
  //   this.column = column
  //   this.file   = options.file
  //   // console.log('setPosition('+line+', '+column+')')
  //   return false
  // }

  // Add position information to the node then returns the node. Wrap a node
  // with this in its parse block to add position metadata.
  function pos (node) {
    // console.log(options.file+': L'+line()+' C'+column())
    if (node.setPosition) {
      node.setPosition(options.file, line(), column())
    }
    return node
  }

  // Forward declarations that will be overwritten parser-extension.js
  p.parseImport = function (name, using) { return [name, using] }
  p.parseExport = function (name) { return [name] }
  p.parseDeclaration = function (lvalue, rvalue) { return [lvalue, rvalue] }
  p.parseClass = function (name, block) { return [name, block] }
  p.parseInit = function (args, block) { return [args, block] }
  p.parseBlock = function (statements) { return statements }
  p.parseIf = function (cond, block, elseIfs, elseBlock) { return [cond, block, elseIfs, elseBlock] }
  p.parseRoot = function (statements) { return ['root'].concat(statements) }
  p.parseBinary = function (left, op, right) { return [left, op, right] }
  p.parseInteger = function (integerString) { return integerString }
  p.parseString = function (string) { return string }
  p.parseBoolean = function (boolean) { return boolean }
  p.parseLeftDeclaration = function (decl, name, type) { return [decl, name, type] }
  p.parseNew = function (name, args) { return [name, args] }
  p.parseFunction = function (name, args, returnType, whenCond, block) { return [name, args, returnType, whenCond, block] }
  p.parseFor = function (init, cond, after, block) { return [init, cond, after, block] }
  p.parseWhile = function (cond, block) { return [cond, block] }
  p.parseChain = function (name, tail) { return [name, tail] }
  p.parseAssignment = function (path, op, expr) { return [path, op, expr] }
  p.parseReturn = function (expr) { return [expr] }

  p.parseExpr = function (expr) { return ['expr', expr] }
  p.parseCallExpr = function (args) { return ['callexpr', args] }
  p.parseCallArgs = function (args) { return ['callargs'].concat(args) }
  p.parseIndexer = function (base, indexer) { return [base, indexer] }
  p.parseIdentifier = function (name) { return name }

  p.parseLeft = function (name, path) { return [name, path] }
  p.parseLeftIndexer = function (expr) { return expr }
  p.parseLeftProperty = function (name) { return name }

  p.parsePathExpr = function (name, path) { return ['pathexpr', name, path] }
  p.parsePathProperty = function (identifier) { return ['pathproperty', identifier] }
  p.parsePathIndexer = function (expr) { return ['pathindexer', expr] }

  p.parseNameType = function (name) { return [name] }
  p.parseFunctionType = function (args, ret) { return [args, ret] }
  p.parseMutli = function (name, args, ret) { return [name, args, ret] }

  if (typeof require !== 'undefined') {
    for (key in p) {
      if (p.hasOwnProperty(key)) {
        delete p[key]
      }
    }
    require('./parser-extension')(p)
  }
}// End preamble


start = __ s:statements __ { return pos(p.parseRoot(s)) }

statements = statement*

// Statements must be ended by a newline, semicolon, end-of-file, or a
// look-ahead right curly brace for end-of-block.
terminator = _ comment? ("\n" / ";" / eof / &"}") __

block = "{" __ s:statements __ "}" { return pos(p.parseBlock(s)) }

statement = s:innerstmt terminator { return s }

innerstmt = modstmt
          / decl
          / ctrl
          / assg
          / multistmt
          / funcstmt
          / expr

modstmt = importstmt
        / exportstmt

importstmt = "import" whitespace "<" i:importpath ">" u:usingpath? { return pos(p.parseImport(i, u)) }
importpath = [A-Za-z0-9-_/.]+ { return text() }
usingpath  = whitespace "using" whitespace n:name e:(_ "," _ name)* {
  return [n].concat((!e) ? [] : e.map(function (a) {
    return a[3]
  }))
}
exportstmt = "export" whitespace n:name   { return pos(p.parseExport(n)) }

ctrl = ifctrl
     / whilectrl
     / forctrl
     / returnctrl

ifctrl = "if" _ c:innerstmt __ b:block ei:(__ elseifcont)* e:(__ elsecont)? {
  ei = ei.map(function (pair) { return pair[1] })
  e  = e ? e[1] : null
  return pos(p.parseIf(c, b, ei, e))
}
// Continuations of the if control with else-ifs
elseifcont = "else" __ "if" _ c:innerstmt __ b:block { return p.parseIf(c, b, null) }
elsecont   = "else" __ b:block { return b }

whilectrl  = "while" _ c:innerstmt _ b:block { return pos(p.parseWhile(c, b)) }
forctrl    = "for" _ i:innerstmt? _ ";" _ c:innerstmt? _ ";" _ a:innerstmt? _ b:block { return pos(p.parseFor(i, c, a, b)) }
returnctrl = "return" e:(_ e:expr)? { return pos(p.parseReturn(e ? e[1] : null)) }

decl = letvardecl
     / classdecl
     / initdecl

classdecl = "class" whitespace n:name _ b:block { return pos(p.parseClass(n, b)) }
initdecl  = "init" _ a:args _ b:block  { return pos(p.parseInit(a, b)) }

// Declaration via let or var keywords
letvardecl = lvalue:leftdecl rvalue:(_ "=" _ expr)? { return pos(p.parseDeclaration(lvalue, rvalue ? rvalue[3] : false)) }
leftdecl = k:("let" / "var") whitespace n:name t:(":" whitespace type)? { return pos(p.parseLeftDeclaration(k, n, t ? t[2] : null)) }

assg = path:leftpath _ op:assgop _ e:expr { return pos(p.parseAssignment(path, op, e)) }
assgop = "="
       / "+="

// Path assignment of existing variables and their indexes/properties
leftpath     = n:identifier path:(leftproperty)* { return p.parseLeft(n, path) }
leftindexer  = "[" _ e:expr _ "]" { return pos(p.parseLeftIndexer(e)) }
leftproperty = "." i:identifier { return pos(p.parseLeftProperty(i)) }

multistmt = "multi" whitespace n:name _ a:args _ r:ret? { return pos(p.parseMulti(n, a, r)) }

expr = e:binaryexpr { return p.parseExpr(e) }

// Binary expressions have highest precedence
binaryexpr = le:unaryexpr _ op:binaryop _ re:binaryexpr { return pos(p.parseBinary(le, op, re)) }
           / unaryexpr

unaryexpr = "!" path:basicexpr { return path }
          / basicexpr

// memberexpr = b:basicexpr c:callexpr     { return pos(p.parseCall(b, c)) }
//            / b:basicexpr e:propertyexpr { return pos(p.parseProperty(b, e)) }
//            / b:basicexpr i:indexerexpr  { return pos(p.parseIndexer(b, i)) }
//            / b:basicexpr                { return b }

basicexpr = "(" e:expr ")" { return e }
          / funcexpr
          / newexpr
          / literalexpr
          / pathexpr

pathexpr = i:identifier c:(pathcomponenet)* { return p.parsePathExpr(i, c) }

pathcomponenet = c:callexpr    { return pos(p.parseCallExpr(c)) }
               / pathproperty
               / indexerexpr

callexpr     = "(" _ args:(expr _ ("," _ expr _)* )? _ ")" { return pos(p.parseCallArgs(args ? transformArgs(args) : [])) }
pathproperty = "." i:identifier { return p.parsePathProperty(i) }
indexerexpr  = "[" _ e:expr _ "]" { return p.parsePathIndexer(e) }

identifier = n:name { return pos(p.parseIdentifier(n)) }

// chainexpr = n:name t:(indexer / property / call)* { return pos(p.parseChain(n, t)) }

newexpr = "new" whitespace n:name _ "(" _ a:(expr _ ("," _ expr _)* )? _ ")" { return pos(p.parseNew(n, a ? transformArgs(a) : [])) }

funcstmt = "func" whitespace n:name _ a:args _ r:ret? _ w:when? _ b:block { return pos(p.parseFunction(n, a, r, w, b)) }
funcexpr = "func" _ a:args _ r:ret? _ b:block { return pos(p.parseFunction(null, a, r, null, b)) }
args     = "(" _ list:arglist? _ ")" { return (list ? list : []) }
arglist  = ( h:arg _ t:("," _ arg _)* ) { return [h].concat(t.map(function (ti) { return ti[2] })) }
arg      = n:argname _ t:(":" _ type)? _ d:("=" _ literalexpr)? { return {name: n, type: (t ? t[2] : null), def: (d ? d[2] : null)} }
argname  = "_" { return text() }
         / name
ret      = "->" whitespace t:type { return t }
when     = "when" _ "(" _ e:expr _ ")" { return e }

// Building blocks

name = [A-Za-z] [A-Za-z0-9_]* { return text() }
type = nametype / functype

nametype = [A-Z] [A-Za-z0-9_]* { return p.parseNameType(text()) }
functype = "(" _ args:argtypelist? _ ")" _ "->" _ ret:type { return p.parseFunctionType(args, ret) }
argtypelist = ( h:type _ t:("," _ type _)* ) { return [h].concat(t.map(function (ti) { return ti[2] })) }

// Literals

literalexpr = i:integer { return p.parseInteger(i) }
            / s:string  { return s }
            / b:boolean { return b }

integer = "0"
        / ("-"? [1-9] [0-9]*) { return text() }

string = '"' c:stringchar* '"' { return p.parseString(c.join('')) }
// Adapted from: https://github.com/pegjs/pegjs/blob/master/examples/javascript.pegjs
stringchar = unescapedchar
           / "\\" sequence:(
                 '"'
               / "\\"
               / "/"
               / "b" { return "\b"; }
               / "f" { return "\f"; }
               / "n" { return "\n"; }
               / "r" { return "\r"; }
               / "t" { return "\t"; }
               / "u" digits:$(HEXDIGIT HEXDIGIT HEXDIGIT HEXDIGIT) {
                   return String.fromCharCode(parseInt(digits, 16));
                 }
             ) { return sequence }

unescapedchar = [\x20-\x21\x23-\x5B\x5D-\u10FFFF]

boolean = b:("true" / "false") { return p.parseBoolean(b) }

// See RFC 4234, Appendix B (http://tools.ietf.org/html/rfc4627)
DIGIT    = [0-9]
HEXDIGIT = [0-9a-f]i

binaryop  = "+"
          / "+"
          / "-"
          / "*"
          / "/"
          / "%"
          / "=="
          / "||"
          / "<"
          / ">"

__ = (comment / "\n" / whitespace)*

// A comment is a pound sign, followed by anything but a newline,
// followed by a non-consumed newline.
comment = "#" [^\n]* &"\n"

whitespace = " " / "\t"
_ = whitespace*


// Utility to be added onto the end of rules to set position info
// pos = ! { return p.setPosition(line(), column()) }

eof = !.
