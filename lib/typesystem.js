
var inherits = require('util').inherits

var types = require('./types')
var AST   = require('./ast')


function TypeError(message) {
  Error.apply(this)
  this.name = 'TypeError'; this.message = message
}
inherits(TypeError, Error)


function Scope (parent) {
  this.parent = (parent === undefined) ? null : parent
  this.locals = {}
}
Scope.prototype.get = function (name) {
  if (this.locals[name] !== undefined) {
    return this.locals[name]
  } else if (this.parent !== null) {
    return this.parent.get(name)
  } else {
    throw new TypeError('Unknown variable: '+name)
  }
}
Scope.prototype.setLocal = function (name, type) {
  if (this.locals[name] !== undefined) {
    throw new TypeError("Can't redefine local: "+name)
  }
  this.locals[name] = type
}


function TypeSystem () {
  this.cache = {}
  this.setupIntrinsics()
}
TypeSystem.prototype.setupIntrinsics = function () {
  this.cache['String'] = new types.String()
  this.cache['Number'] = new types.Number()
  // Alias Integer to Number
  this.cache['Integer'] = new types.Number()
}
TypeSystem.prototype.findByName = function (name) {
  var type = this.cache[name]
  if (type === undefined) {
    throw new TypeError('Type not found: '+name)
  }
  return type
}

function assertInstanceOf(value, type, msg) {
  if (value instanceof type) { return; }
  throw new Error(msg)
}


// AST typing -----------------------------------------------------------------

TypeSystem.prototype.walk = function (rootNode) {
  assertInstanceOf(rootNode, AST.Root, "Node must be root")

  var self = this
  var topLevelScope = new Scope()
  rootNode.statements.forEach(function (stmt) {
    self.visitStatement(stmt, topLevelScope)
  })
}

TypeSystem.prototype.visitBlock = function (node, scope) {
  var self = this
  node.statements.forEach(function (stmt) {
    self.visitStatement(stmt, scope)
  })
}

TypeSystem.prototype.visitStatement = function (node, scope) {
  switch (node.constructor) {
    case AST.Assignment:
      if (node.lvalue instanceof AST.Let) {
        this.visitLet(node, scope)
      } else if (node.lvalue instanceof AST.Var) {
        this.visitVar(node, scope)
      } else {
        throw new TypeError('Cannot visit Assignment type: '+node.lvalue.constructor.name)
      }
      break
    case AST.If:
      this.visitIf(node, scope)
      break
    case AST.For:
      this.visitFor(node, scope)
      break
    case AST.Return:
      this.visitReturn(node, scope)
      break
    default:
      throw new TypeError("Don't know how to visit: "+node.constructor.name)
      // node.print()
      break
  }
}

TypeSystem.prototype.visitFor = function (node, scope) {
  console.log(node)

  // TODO: Check that the condition (`node.cond`) resolves to a
  //       boolean-checkable type.

  this.visitStatement(node.init, scope)
  this.visitExpression(node.cond, scope)
  this.visitExpression(node.after, scope)

  var blockScope = new Scope(scope)
  this.visitBlock(node.block, blockScope)
}

TypeSystem.prototype.visitIf = function (node, scope) {
  assertInstanceOf(node.block, AST.Block, 'Expected Block in If block')

  this.visitExpression(node.cond, scope)

  var blockScope = new Scope(scope)
  this.visitBlock(node.block, blockScope)
}

TypeSystem.prototype.visitReturn = function (node, scope) {
  if (node.expr === null || node.expr === undefined) {
    throw new TypeError('Cannot handle empty Return')
  }
  var expr = node.expr
  var exprType = this.resolveExpression(expr, scope)
  node.type = exprType
}

TypeSystem.prototype.visitLet = function (node, scope) {
  var lvalueType = new types.Unknown()
  var name       = node.lvalue.name

  // Create a scope inside the Let statement for recursive calls
  var letScope = new Scope(scope)
  letScope.setLocal(name, lvalueType)

  // rvalue is an expression so let's determine its type first.
  var rvalueType = this.resolveExpression(node.rvalue, letScope, function (immediateType) {
    lvalueType.known = immediateType
  })
  scope.setLocal(name, rvalueType)
}
TypeSystem.prototype.visitVar = TypeSystem.prototype.visitLet

TypeSystem.prototype.resolveExpression = function (expr, scope, immediate) {
  // If we've already deduced the type of this then just return it
  if (expr.type) { return expr.type }

  this.visitExpression(expr, scope, immediate)

  if (expr.type === null || expr.type === undefined) {
    console.log(expr)
    throw new TypeError('Failed to resolve type')
  }
  return expr.type
}

TypeSystem.prototype.visitExpression = function (node, scope, immediate) {
  switch (node.constructor) {
    case AST.Function:
      this.visitFunction(node, scope, immediate)
      break
    case AST.Binary:
      this.visitBinary(node, scope)
      break
    case AST.Chain:
      this.visitChain(node, scope)
      break
    default:
      throw new Error("Can't walk: "+node.constructor.name)
  }
}

TypeSystem.prototype.visitBinary = function (node, scope) {
  var lexprType = this.resolveExpression(node.lexpr, scope)
  var rexprType = this.resolveExpression(node.rexpr, scope)

  if (lexprType.equals(rexprType)) {
    node.type = lexprType
  } else {
    throw new TypeError('Unequal types in binary operation: '+lexprType.inspect()+' </> '+rexprType.inspect())
  }
}

TypeSystem.prototype.visitFunction = function (node, parentScope, immediate) {
  if (node.type) { return node.type }
  var self = this
  var type = new types.Function()

  if (node.ret) {
    type.ret = this.findByName(node.ret)
  }

  // If we have a callback for the immediate (not-yet-fully resolved type)
  // then call it now.
  if (immediate !== undefined) {
    immediate(type)
  }

  var functionScope = new Scope(parentScope)

  node.args.forEach(function (arg) {
    var argType = self.findByName(arg.type)
    functionScope.setLocal(arg.name, argType)
  })

  // Begin by visiting our block
  this.visitBlock(node.block, functionScope)

  if (type.ret) {
    // TODO: If the type is already known from the function definition then
    //       validate the returns match up with that.
    node.type = type
    return
  }
  throw new Error('Inferred return types not supported yet')

  // Then we'll find all the `return`s and get their types
  var returns = []
}

var know = function (type) {
  if (type instanceof types.Unknown) {
    if (type.known === null) {
      throw new TypeError('Unknown type')
    }
    return type.known
  }
  return type
}

TypeSystem.prototype.visitChain = function (node, scope) {
  var type = know(scope.get(node.name))
  node.tail.forEach(function (item) {
    if (item instanceof AST.Call) {
      assertInstanceOf(type, types.Function, 'Trying to call non-Function')
      // TODO: Type-check arguments
      // console.log(item.constructor.name+': '+item.toString())
      // Replace current type with type that's going to be returned
      var returnType = type.ret
      type = returnType
    } else {
      throw new TypeError('Cannot handle Chain item of type: '+item.constructor.name)
    }
  })
  node.type = type
}


module.exports = {TypeSystem: TypeSystem}