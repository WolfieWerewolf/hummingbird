var types = require('../types')

module.exports = function (TypeSystem) {

  TypeSystem.prototype.bootstrap = function () {
    // The root object is the base object from which all objects descend
    var rootObject = new types.Object('fake')
    rootObject.supertype = null
    rootObject.isRoot    = true

    // Setup the basic intrinsic types (Any, Object, Integer, etc.)
    this.bootstrapIntrinsicTypes(rootObject)

    // Expose rootObject to later functions
    this.rootObject = rootObject

    // Set up our built-ins
    this.bootstrapStd()
    this.bootstrapConsole(rootObject)
  }// bootstrap()

  TypeSystem.prototype.bootstrapIntrinsicTypes = function (rootObject) {
    var Integer = new types.Integer(rootObject)
    this.root.setLocal('Any',     new types.Any())
    this.root.setLocal('Object',  new types.Object(rootObject))
    this.root.setLocal('String',  new types.String(rootObject))
    this.root.setLocal('Integer', Integer)
    this.root.setLocal('Boolean', new types.Boolean(rootObject))
    this.root.setLocal('Void',    new types.Void(rootObject))
  }

  TypeSystem.prototype.bootstrapConsole = function (rootObject) {
    var consoleType = new types.Object(this.root.getLocal('Object'))
    consoleType.intrinsic = true
    consoleType.name      = 'BuiltinConsole'
    // Create the `log(...)` function and add it to the console's type as a
    // read-only property
    var consoleLogFunction = new types.Function(rootObject, [this.root.getLocal('Any')], this.root.getLocal('Void'))
    consoleType.setTypeOfProperty('log', consoleLogFunction)
    consoleType.setFlagsOfProperty('log', 'r')
    // Create a faux instance of the console and add it to the root scope
    var consoleInstance = new types.Instance(consoleType)
    this.root.setLocal('console', consoleInstance)
  }

  TypeSystem.prototype.bootstrapStd = function () {
    var std = new types.Module('std')
    this.root.setLocal('std', std)

    var core = new types.Module('core')
    core.setParent(std)
    std.addChild(core)

    var typs = new types.Module('types')
    typs.setParent(core)
    core.addChild(typs)

    this.bootstrapStdCoreTypesString(typs)
  }

  TypeSystem.prototype.bootstrapStdCoreTypesString = function (typs) {
    var stringModule = new types.Module('string'),
        StringType   = this.root.getLocal('String')
    stringModule.setParent(typs)
    typs.addChild(stringModule)

    var self = this
    function addInstanceMethodAndShim (module, receiverType, methodName, returnType) {
      var moduleMethod = new types.Function(self.rootObject, [receiverType], returnType)
      stringModule.setTypeOfProperty(methodName, moduleMethod)
      var instanceMethod = new types.Function(self.rootObject, [], returnType)
      instanceMethod.isInstanceMethod = true
      instanceMethod.shimFor          = moduleMethod
      StringType.setTypeOfProperty(methodName, instanceMethod)
    }

    // Add function to module and the String type
    /*
    var uppercase = new types.Function(this.rootObject, [this.root.getLocal('String')], this.root.getLocal('String'))
    stringModule.setTypeOfProperty('uppercase', uppercase)
    var uppercaseMethod = new types.Function(this.rootObject, [], this.root.getLocal('String'))
    uppercaseMethod.isInstanceMethod = true
    uppercaseMethod.shimFor          = uppercase
    StringType.setTypeOfProperty('uppercase', uppercaseMethod)
    */
    addInstanceMethodAndShim(stringModule, StringType, 'uppercase', StringType)
    addInstanceMethodAndShim(stringModule, StringType, 'lowercase', StringType)
    
  }

}// module.exports
